import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { VpnProfileRepository, DirectVpnProfile, DirectVpnProfileProvider } from './VpnProfileRepository';

export interface ImportedSubscription {
  id: string;
  name: string;
  /** URL-based subscription (vless/vmess/trojan/https). Empty if config-based. */
  url: string;
  /** Raw sing-box JSON config. Empty if URL-based. */
  singBoxConfig: string;
  addedAt: string;
}

const VLESS_TUNNEL_HINT: string =
  'Ссылка сохранена. Для туннеля нужен JSON-конфиг или https-подписка с sing-box.';

class ImportedProvider implements DirectVpnProfileProvider {
  private readonly subName: string;
  private readonly subConfig: string;

  constructor(name: string, config: string) {
    this.subName = name;
    this.subConfig = config;
  }

  getProfile(_serverId: string): Promise<DirectVpnProfile | null> {
    const profile: DirectVpnProfile = {
      id: 'imported',
      serverName: this.subName,
      singBoxConfig: this.subConfig,
      address: '',
      ipv6Address: '',
      dns: '',
      mtu: 1500,
      ipv6: false
    };
    return Promise.resolve<DirectVpnProfile | null>(profile);
  }
}

/** Safe string getter from preferences ValueType. */
function prefsGetString(prefs: preferences.Preferences, key: string, fallback: string): string {
  const v = prefs.getSync(key, fallback);
  if (typeof v === 'string') {
    return v;
  }
  return fallback;
}

function isSingBoxJsonText(text: string): boolean {
  const t = text.trim();
  if (!t.startsWith('{')) {
    return false;
  }
  return t.includes('"outbounds"') || t.includes('"inbounds"') || t.includes('"dns"');
}

interface HostPortPair {
  host: string;
  port: number;
}

function jsonQuote(value: string): string {
  return JSON.stringify(value);
}

function parseQueryMap(query: string): Record<string, string> {
  const out: Record<string, string> = {};
  if (query.length === 0) {
    return out;
  }
  const parts = query.split('&');
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    const eq = part.indexOf('=');
    if (eq < 0) {
      out[decodeURIComponent(part)] = '';
    } else {
      const k = decodeURIComponent(part.substring(0, eq));
      const v = decodeURIComponent(part.substring(eq + 1));
      out[k] = v;
    }
  }
  return out;
}

function splitHostPort(hostPort: string): HostPortPair | null {
  if (hostPort.length === 0) {
    return null;
  }
  if (hostPort.startsWith('[')) {
    const end = hostPort.indexOf(']');
    if (end < 0) {
      return null;
    }
    const host = hostPort.substring(1, end);
    let port = 443;
    if (end + 1 < hostPort.length && hostPort.charAt(end + 1) === ':') {
      const p = parseInt(hostPort.substring(end + 2), 10);
      if (!Number.isNaN(p)) {
        port = p;
      }
    }
    const pair: HostPortPair = { host: host, port: port };
    return pair;
  }
  const colon = hostPort.lastIndexOf(':');
  if (colon < 0) {
    const pair: HostPortPair = { host: hostPort, port: 443 };
    return pair;
  }
  const host = hostPort.substring(0, colon);
  const port = parseInt(hostPort.substring(colon + 1), 10);
  if (Number.isNaN(port)) {
    const fallback: HostPortPair = { host: hostPort, port: 443 };
    return fallback;
  }
  const pair: HostPortPair = { host: host, port: port };
  return pair;
}

export class ImportedSubscriptionStore {
  private static readonly PREFS_NAME: string = 'vpndirect_imported_subs';
  private static readonly KEY_LIST: string = 'sub_list';
  private static readonly KEY_ACTIVE: string = 'sub_active';

  private static prefs: preferences.Preferences | null = null;
  /** In-memory cache updated on every write. */
  private static cache: ImportedSubscription[] = [];
  private static cachedActiveId: string = '';

  static init(context: common.UIAbilityContext): void {
    try {
      ImportedSubscriptionStore.prefs = preferences.getPreferencesSync(context, {
        name: ImportedSubscriptionStore.PREFS_NAME
      });
      ImportedSubscriptionStore.cache = ImportedSubscriptionStore.parseList();
      ImportedSubscriptionStore.cachedActiveId = ImportedSubscriptionStore.readActiveId();
    } catch (err) {
      console.error(`ImportedSubscriptionStore: init failed: ${err}`);
    }
  }

  static list(): ImportedSubscription[] {
    return ImportedSubscriptionStore.cache;
  }

  static activeId(): string {
    return ImportedSubscriptionStore.cachedActiveId;
  }

  static active(): ImportedSubscription | null {
    const id = ImportedSubscriptionStore.cachedActiveId;
    if (id.length === 0) {
      return null;
    }
    const found = ImportedSubscriptionStore.cache.find((s: ImportedSubscription) => s.id === id);
    return found !== undefined ? found : null;
  }

  static add(sub: ImportedSubscription): void {
    const list = ImportedSubscriptionStore.cache;
    const idx = list.findIndex((s: ImportedSubscription) => s.id === sub.id);
    if (idx >= 0) {
      list[idx] = sub;
    } else {
      list.push(sub);
    }
    ImportedSubscriptionStore.cache = list;
    ImportedSubscriptionStore.flushList(list);
  }

  static setActive(id: string): void {
    ImportedSubscriptionStore.cachedActiveId = id;
    const prefs = ImportedSubscriptionStore.prefs;
    if (prefs !== null) {
      prefs.putSync(ImportedSubscriptionStore.KEY_ACTIVE, id);
      prefs.flush().catch((err: Error) => {
        console.warn(`ImportedSubscriptionStore: flush error: ${err?.message ?? err}`);
      });
    }
    ImportedSubscriptionStore.wireProvider();
  }

  /** User hint when URL is stored but tunnel config is missing. */
  static urlOnlyTunnelHint(): string {
    return VLESS_TUNNEL_HINT;
  }

  /**
   * Best-effort sing-box JSON from a single vless:// share link.
   * Returns null when parsing or transport params are unsupported.
   */
  static trySingBoxFromVlessUri(uri: string): string | null {
    const trimmed = uri.trim();
    if (!trimmed.startsWith('vless://')) {
      return null;
    }
    const rest = trimmed.substring('vless://'.length);
    let main = rest;
    const hashIdx = rest.indexOf('#');
    if (hashIdx >= 0) {
      main = rest.substring(0, hashIdx);
    }
    const qIdx = main.indexOf('?');
    let query = '';
    let authority = main;
    if (qIdx >= 0) {
      query = main.substring(qIdx + 1);
      authority = main.substring(0, qIdx);
    }
    const atIdx = authority.indexOf('@');
    if (atIdx < 0) {
      return null;
    }
    const uuid = authority.substring(0, atIdx);
    const hostPort = splitHostPort(authority.substring(atIdx + 1));
    if (hostPort === null || uuid.length === 0) {
      return null;
    }
    const params = parseQueryMap(query);
    const security = (params['security'] ?? 'none').toLowerCase();
    const network = (params['type'] ?? 'tcp').toLowerCase();

    let outbound =
      `"type":"vless","tag":"proxy","server":${jsonQuote(hostPort.host)},"server_port":${hostPort.port},"uuid":${jsonQuote(uuid)}`;
    const flow = params['flow'];
    if (flow !== undefined && flow.length > 0) {
      outbound += `,"flow":${jsonQuote(flow)}`;
    }

    if (network === 'ws') {
      let transport = '"type":"ws"';
      const path = params['path'];
      if (path !== undefined && path.length > 0) {
        transport += `,"path":${jsonQuote(path)}`;
      }
      const wsHost = params['host'];
      if (wsHost !== undefined && wsHost.length > 0) {
        transport += `,"headers":{"Host":${jsonQuote(wsHost)}}`;
      }
      outbound += `,"transport":{${transport}}`;
    } else if (network !== 'tcp') {
      return null;
    }

    if (security === 'tls' || security === 'reality') {
      let tls = '"enabled":true';
      const sni = params['sni'] ?? params['peer'];
      if (sni !== undefined && sni.length > 0) {
        tls += `,"server_name":${jsonQuote(sni)}`;
      }
      const fp = params['fp'] ?? 'chrome';
      tls += `,"utls":{"enabled":true,"fingerprint":${jsonQuote(fp)}}`;
      if (security === 'reality') {
        const pbk = params['pbk'];
        const sid = params['sid'] ?? '';
        if (pbk === undefined || pbk.length === 0) {
          return null;
        }
        tls += `,"reality":{"enabled":true,"public_key":${jsonQuote(pbk)},"short_id":${jsonQuote(sid)}}`;
      }
      outbound += `,"tls":{${tls}}`;
    } else if (security !== 'none') {
      return null;
    }

    return `{"log":{"level":"warn"},"inbounds":[],"outbounds":[{${outbound}},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}`;
  }

  /**
   * GET an https subscription URL and persist sing-box JSON when detected.
   * Returns a short user-facing status line (may be empty).
   */
  static async fetchAndApplyActiveUrl(): Promise<string> {
    const active = ImportedSubscriptionStore.active();
    if (active === null) {
      return '';
    }
    if (active.singBoxConfig.length > 0) {
      return '';
    }
    const url = active.url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return '';
    }
    try {
      const body = await ImportedSubscriptionStore.httpGetBody(url);
      const config = ImportedSubscriptionStore.configFromSubscriptionBody(body);
      if (config === null) {
        return '';
      }
      const updated: ImportedSubscription = {
        id: active.id,
        name: active.name,
        url: active.url,
        singBoxConfig: config,
        addedAt: active.addedAt
      };
      ImportedSubscriptionStore.add(updated);
      ImportedSubscriptionStore.wireProvider();
      return 'Конфиг sing-box загружен из подписки.';
    } catch (err) {
      const msg = err instanceof Error ? err.message : `${err}`;
      console.warn(`ImportedSubscriptionStore: subscription fetch failed: ${msg}`);
      return '';
    }
  }

  /** Wire the active import as the VpnProfileRepository provider (sing-box config only). */
  static wireProvider(): void {
    const active = ImportedSubscriptionStore.active();
    if (active === null) {
      return;
    }
    if (active.singBoxConfig.length === 0) {
      console.info(`ImportedSubscriptionStore: URL-based subscription "${active.name}" active — no sing-box config yet`);
      return;
    }
    VpnProfileRepository.setProvider(new ImportedProvider(active.name, active.singBoxConfig));
    console.info(`ImportedSubscriptionStore: wired sing-box provider for "${active.name}"`);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private static normalizeSubscriptionBody(raw: string): string {
    let text = raw.trim();
    if (text.length === 0) {
      return text;
    }
    if (isSingBoxJsonText(text) || text.includes('proxies:') || text.includes('vless://')) {
      return text;
    }
    try {
      const helper = new util.Base64Helper();
      const bytes = helper.decodeSync(text.replace(/\s/g, ''));
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const decoded = decoder.decodeToString(bytes);
      if (decoded.trim().length > 0) {
        return decoded.trim();
      }
    } catch {
      // not base64
    }
    return text;
  }

  private static configFromSubscriptionBody(raw: string): string | null {
    const body = ImportedSubscriptionStore.normalizeSubscriptionBody(raw);
    if (body.length === 0) {
      return null;
    }
    if (isSingBoxJsonText(body)) {
      return body.trim();
    }
    const lines = body.split(/\r?\n/).map((line: string) => line.trim()).filter((line: string) => line.length > 0);
    const vlessLines = lines.filter((line: string) => line.startsWith('vless://'));
    if (vlessLines.length === 1) {
      return ImportedSubscriptionStore.trySingBoxFromVlessUri(vlessLines[0]);
    }
    return null;
  }

  private static async httpGetBody(url: string): Promise<string> {
    const client = http.createHttp();
    try {
      const response = await client.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 25000,
        readTimeout: 40000
      });
      const code = response.responseCode;
      if (code < 200 || code >= 300) {
        throw new Error(`HTTP ${code}`);
      }
      if (typeof response.result === 'string') {
        return response.result;
      }
      return JSON.stringify(response.result ?? '');
    } finally {
      client.destroy();
    }
  }

  private static parseList(): ImportedSubscription[] {
    const prefs = ImportedSubscriptionStore.prefs;
    if (prefs === null) {
      return [];
    }
    const json: string = prefsGetString(prefs, ImportedSubscriptionStore.KEY_LIST, '[]');
    try {
      return JSON.parse(json) as ImportedSubscription[];
    } catch {
      return [];
    }
  }

  private static readActiveId(): string {
    const prefs = ImportedSubscriptionStore.prefs;
    if (prefs === null) {
      return '';
    }
    return prefsGetString(prefs, ImportedSubscriptionStore.KEY_ACTIVE, '');
  }

  private static flushList(list: ImportedSubscription[]): void {
    const prefs = ImportedSubscriptionStore.prefs;
    if (prefs === null) {
      return;
    }
    try {
      prefs.putSync(ImportedSubscriptionStore.KEY_LIST, JSON.stringify(list));
      prefs.flush().catch((err: Error) => {
        console.warn(`ImportedSubscriptionStore: flush error: ${err?.message ?? err}`);
      });
    } catch (err) {
      console.error(`ImportedSubscriptionStore: flush list failed: ${err}`);
    }
  }
}
