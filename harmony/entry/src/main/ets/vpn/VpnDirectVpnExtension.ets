import { vpnExtension, VpnExtensionAbility } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HarmonyCoreBridge } from './HarmonyCoreBridge';

/**
 * VPN Direct HarmonyOS NEXT platform adapter.
 *
 * Platform boundary only: HarmonyOS owns the TUN lifecycle, while the
 * VPN Direct Core owns protocol/session processing. No server address,
 * subscription URL, credential or executable code is accepted from config.
 */
export default class VpnDirectVpnExtension extends VpnExtensionAbility {
  private vpnConnection?: vpnExtension.VpnConnection;
  private vpnId?: string;
  private tunFd: number = -1;
  private core?: HarmonyCoreBridge;

  onCreate(want: Want): void {
    hilog.info(0xD1, 'VPNDirect', 'VPN extension created');
    this.vpnConnection = vpnExtension.createVpnConnection(this.context);
    this.core = new HarmonyCoreBridge();
  }

  async start(profileJson: string): Promise<void> {
    if (!this.vpnConnection || !this.core) {
      throw new Error('VPN extension is not initialized');
    }

    const profile = JSON.parse(profileJson) as Record<string, Object>;
    const address = this.stringValue(profile['address'], '172.19.0.2');
    const dns = this.stringValue(profile['dns'], '1.1.1.1');
    const mtu = this.numberValue(profile['mtu'], 1400);
    const ipv6 = this.booleanValue(profile['ipv6'], true);

    const config = {
      addresses: [{ address, prefixLength: 32 }],
      routes: [{ address: '0.0.0.0', prefixLength: 0 }],
      dnsAddresses: [dns],
      mtu,
      isIPv6: ipv6,
      isInternal: false,
      isBlocking: false
    };

    this.tunFd = await this.vpnConnection.create(config);
    if (this.tunFd < 0) {
      throw new Error('HarmonyOS VPN TUN creation failed');
    }

    await this.core.start(this.tunFd, profileJson);
    this.vpnId = 'vpndirect-' + Date.now().toString();
    hilog.info(0xD1, 'VPNDirect', 'VPN started, tunFd=%{public}d', this.tunFd);
  }

  async stop(): Promise<void> {
    try {
      await this.core?.stop();
    } finally {
      if (this.vpnConnection && this.vpnId) {
        await this.vpnConnection.destroy(this.vpnId);
      }
      this.vpnId = undefined;
      this.tunFd = -1;
    }
  }

  onDestroy(): void {
    this.stop().catch(() => undefined);
    hilog.info(0xD1, 'VPNDirect', 'VPN extension destroyed');
  }

  private stringValue(value: Object | undefined, fallback: string): string {
    return typeof value === 'string' && value.length > 0 ? value : fallback;
  }

  private numberValue(value: Object | undefined, fallback: number): number {
    return typeof value === 'number' && value > 0 ? value : fallback;
  }

  private booleanValue(value: Object | undefined, fallback: boolean): boolean {
    return typeof value === 'boolean' ? value : fallback;
  }
}
