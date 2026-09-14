import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { PasteboardHelper } from '../util/PasteboardHelper';
import { ImportedSubscriptionStore, ImportedSubscription } from '../vpn/ImportedSubscriptionStore';
import { common } from '@kit.AbilityKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function isSingBoxJson(text: string): boolean {
  const t = text.trim();
  if (!t.startsWith('{')) {
    return false;
  }
  return t.includes('"outbounds"') || t.includes('"inbounds"') || t.includes('"dns"');
}

function isSubscriptionUrl(text: string): boolean {
  return text.startsWith('vless://') ||
    text.startsWith('vmess://') ||
    text.startsWith('trojan://') ||
    text.startsWith('ss://') ||
    text.startsWith('https://') ||
    text.startsWith('http://');
}

/** Normalize share-link / happ:// into a usable import URL. */
function normalizeImportURL(raw: string): string {
  const t = raw.trim();
  // happ:// scheme — unwrap the URL parameter
  if (t.startsWith('happ://')) {
    const qIdx = t.indexOf('?');
    if (qIdx >= 0) {
      const params = t.substring(qIdx + 1).split('&');
      for (const p of params) {
        const eq = p.indexOf('=');
        if (eq >= 0) {
          const key = decodeURIComponent(p.substring(0, eq));
          const val = decodeURIComponent(p.substring(eq + 1));
          if (key === 'url' || key === 'sub') {
            return normalizeImportURL(val);
          }
        }
      }
    }
  }
  // vpn:// → https://
  if (t.startsWith('vpn://')) {
    return 'https://' + t.substring(6);
  }
  return t;
}

function extractNameFromUrl(url: string): string {
  try {
    const hashIdx: number = url.indexOf('#');
    if (hashIdx >= 0 && hashIdx < url.length - 1) {
      return decodeURIComponent(url.substring(hashIdx + 1));
    }
    const slashSlash: number = url.indexOf('://');
    if (slashSlash >= 0) {
      const afterScheme: string = url.substring(slashSlash + 3);
      const slashIdx: number = afterScheme.indexOf('/');
      return slashIdx >= 0 ? afterScheme.substring(0, slashIdx) : afterScheme;
    }
  } catch {
    // ignore
  }
  return 'Импортированная подписка';
}

async function performImport(text: string): Promise<string> {
  const normalized = normalizeImportURL(text.trim());
  const trimmed: string = normalized;
  if (trimmed.length === 0) {
    throw new Error('Текст пуст');
  }
  const jsonBased: boolean = isSingBoxJson(trimmed);
  const urlBased: boolean = isSubscriptionUrl(trimmed);
  if (!jsonBased && !urlBased) {
    throw new Error('Не удалось распознать формат. Введите ссылку (vless/vmess/https) или sing-box JSON.');
  }
  let singBoxConfig: string = jsonBased ? trimmed : '';
  if (urlBased && trimmed.startsWith('vless://') && singBoxConfig.length === 0) {
    const wrapped = ImportedSubscriptionStore.trySingBoxFromVlessUri(trimmed);
    if (wrapped !== null) {
      singBoxConfig = wrapped;
    }
  }
  const sub: ImportedSubscription = {
    id: `import_${Date.now()}`,
    name: jsonBased ? 'Конфигурация sing-box' : extractNameFromUrl(trimmed),
    url: urlBased ? trimmed : '',
    singBoxConfig: singBoxConfig,
    addedAt: new Date().toISOString()
  };
  ImportedSubscriptionStore.add(sub);
  ImportedSubscriptionStore.setActive(sub.id);

  const notes: string[] = [];
  if (sub.url.startsWith('http://') || sub.url.startsWith('https://')) {
    const fetchNote = await ImportedSubscriptionStore.fetchAndApplyActiveUrl();
    if (fetchNote.length > 0) {
      notes.push(fetchNote);
    }
  }
  const active = ImportedSubscriptionStore.active();
  if (active !== null && active.singBoxConfig.length === 0 && active.url.length > 0) {
    notes.push(ImportedSubscriptionStore.urlOnlyTunnelHint());
  }

  // Signal AppShell to navigate to Management after import
  AppStorage.setOrCreate('direct_import_ts', Date.now());

  if (notes.length === 0) {
    return sub.name;
  }
  return `${sub.name}\n${notes.join('\n')}`;
}

// ---------------------------------------------------------------------------
// Shared builders
// ---------------------------------------------------------------------------

@Component
struct ImportPageHeader {
  @Prop kicker: string = '';
  @Prop title: string = '';
  @Prop subtitle: string = '';
  onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button('‹')
          .fontSize(30)
          .fontColor(DirectTheme.muted)
          .backgroundColor(Color.Transparent)
          .width(38)
          .height(38)
          .onClick(() => {
            DirectHaptics.navigation();
            this.onClose();
          });
        Column() {
          Text(this.kicker)
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace');
          Text(this.title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .margin({ top: 4 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      }.height(64).width('100%');
      Text(this.subtitle)
        .fontSize(11)
        .fontColor(DirectTheme.muted)
        .width('100%')
        .margin({ bottom: 18 });
    }.width('100%');
  }
}

@Component
struct ImportActionButton {
  @Prop label: string = 'ИМПОРТИРОВАТЬ';
  @Prop busy: boolean = false;
  onTap: () => void = () => {};

  build() {
    Row() {
      Text(this.busy ? '…' : this.label)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.acid)
        .fontFamily('monospace');
      Blank();
      Text('→').fontSize(13).fontColor(DirectTheme.acid);
    }
    .width('100%')
    .height(52)
    .padding({ left: 15, right: 15 })
    .backgroundColor(DirectTheme.ink)
    .onClick(() => {
      if (!this.busy) {
        DirectHaptics.selection();
        this.onTap();
      }
    });
  }
}

@Component
struct ImportStatusBanner {
  @Prop errorText: string = '';
  @Prop successText: string = '';

  build() {
    Column() {
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(12)
          .fontColor('#CC0000')
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: '#CC0000' });
      }
      if (this.successText.length > 0) {
        Text(this.successText)
          .fontSize(12)
          .fontColor(DirectTheme.green)
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: DirectTheme.green });
      }
    }.width('100%');
  }
}

// ---------------------------------------------------------------------------
// ImportClipboard flow  (C + D)
// ---------------------------------------------------------------------------

@Component
struct DirectImportClipboardFlow {
  onClose: () => void = () => {};
  @State private clipboardText: string = '';
  @State private errorText: string = '';
  @State private successText: string = '';
  @State private busy: boolean = false;
  @State private loaded: boolean = false;
  @State private manualText: string = '';
  @State private showManual: boolean = false;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    void this.readClipboard(ctx);
  }

  private async readClipboard(context: common.UIAbilityContext): Promise<void> {
    try {
      const text: string = await PasteboardHelper.readTextWithContext(context);
      this.loaded = true;
      if (text.trim().length === 0) {
        this.errorText = 'Буфер обмена пуст. Скопируйте ссылку подписки и нажмите снова.';
        return;
      }
      this.clipboardText = text.trim();
      // Auto-run import on appear
      void this.runImport(this.clipboardText);
    } catch (err) {
      this.loaded = true;
      const msg = err instanceof Error ? err.message : `${err}`;
      this.errorText = msg.length > 0 ? msg : 'Не удалось прочитать буфер обмена';
    }
  }

  private async runImport(text: string): Promise<void> {
    if (this.busy || text.trim().length === 0) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.successText = '';
    try {
      const name: string = await performImport(text);
      this.successText = `✓ Импортировано: ${name}`;
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : `${err}`;
      this.errorText = msg;
    } finally {
      this.busy = false;
    }
  }

  private async retryClipboard(): Promise<void> {
    this.errorText = '';
    this.clipboardText = '';
    this.loaded = false;
    const ctx = getContext(this) as common.UIAbilityContext;
    void this.readClipboard(ctx);
  }

  build() {
    Scroll() {
      Column() {
        ImportPageHeader({
          kicker: 'DIRECT / IMPORT · CLIPBOARD',
          title: 'Буфер обмена',
          subtitle: 'Автоматически считывает ссылку или конфиг из буфера.',
          onClose: this.onClose
        });
        ImportStatusBanner({ errorText: this.errorText, successText: this.successText });
        if (!this.loaded) {
          Text('Читаю буфер обмена…')
            .fontSize(13)
            .fontColor(DirectTheme.muted)
            .margin({ top: 20 });
        } else if (this.clipboardText.length > 0 && this.successText.length === 0) {
          Text('СОДЕРЖИМОЕ БУФЕРА')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace')
            .margin({ top: 16, bottom: 6 });
          Text(this.clipboardText.length > 120
            ? `${this.clipboardText.substring(0, 120)}…`
            : this.clipboardText)
            .fontSize(10)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace')
            .width('100%')
            .padding(10)
            .backgroundColor(DirectTheme.fieldFill)
            .border({ width: 1, color: DirectTheme.line })
            .margin({ bottom: 14 });
          ImportActionButton({
            label: 'ИМПОРТИРОВАТЬ',
            busy: this.busy,
            onTap: () => { void this.runImport(this.clipboardText); }
          });
        }

        // ПОВТОРИТЬ button — shown when empty or on error
        if (this.loaded && this.successText.length === 0) {
          Row() {
            Text('↺  ПОВТОРИТЬ ЧТЕНИЕ')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
            Blank();
          }
          .width('100%')
          .height(46)
          .padding({ left: 15, right: 15 })
          .border({ width: 1, color: DirectTheme.line })
          .margin({ top: 12 })
          .onClick(() => {
            DirectHaptics.selection();
            void this.retryClipboard();
          });
        }

        // Manual paste TextArea fallback (critical when system blocks clipboard)
        Row() {
          Text('+ ВСТАВИТЬ ВРУЧНУЮ')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace');
          Blank();
          Text(this.showManual ? '▲' : '▼')
            .fontSize(10)
            .fontColor(DirectTheme.acid);
        }
        .width('100%')
        .height(46)
        .padding({ left: 14, right: 14 })
        .backgroundColor(DirectTheme.ink)
        .margin({ top: 14 })
        .onClick(() => {
          DirectHaptics.selection();
          this.showManual = !this.showManual;
        });

        if (this.showManual) {
          Text('ССЫЛКА ИЛИ КОНФИГ')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace')
            .margin({ top: 12, bottom: 6 });
          TextArea({ placeholder: 'vless://… или https://… · удерживайте для вставки', text: this.manualText })
            .height(100)
            .padding({ left: 13, right: 13, top: 10, bottom: 10 })
            .backgroundColor(DirectTheme.fieldFill)
            .border({ width: 1, color: DirectTheme.line })
            .fontSize(11)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace')
            .margin({ bottom: 10 })
            .onChange((v: string) => { this.manualText = v; });
          if (this.manualText.trim().length > 0) {
            ImportActionButton({
              label: 'ИМПОРТИРОВАТЬ',
              busy: this.busy,
              onTap: () => { void this.runImport(this.manualText); }
            });
          }
        }

        if (this.successText.length > 0) {
          Row() {
            Text('ЗАКРЫТЬ')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
            Blank();
            Text('✕').fontSize(12).fontColor(DirectTheme.ink);
          }
          .width('100%')
          .height(52)
          .padding({ left: 15, right: 15 })
          .backgroundColor(DirectTheme.acid)
          .margin({ top: 10 })
          .onClick(() => {
            DirectHaptics.navigation();
            this.onClose();
          });
        }
        Blank().height(28);
      }.padding({ left: 20, right: 20, top: 18, bottom: 28 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

// ---------------------------------------------------------------------------
// ImportText flow — manual URL  (also used as QR fallback)
// ---------------------------------------------------------------------------

@Component
struct DirectImportTextFlow {
  onClose: () => void = () => {};
  @Prop qrMode: boolean = false;
  @State private urlText: string = '';
  @State private errorText: string = '';
  @State private successText: string = '';
  @State private busy: boolean = false;

  aboutToAppear(): void {
    // Pre-fill from QR scan if available
    const pending: string = AppStorage.get<string>('pending_import_text') ?? '';
    if (pending.length > 0) {
      this.urlText = pending;
      AppStorage.setOrCreate('pending_import_text', '');
    }
  }

  private async runImport(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.successText = '';
    try {
      const name: string = await performImport(this.urlText);
      this.successText = `✓ Импортировано: ${name}`;
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : `${err}`;
      this.errorText = msg;
    } finally {
      this.busy = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        ImportPageHeader({
          kicker: this.qrMode ? 'DIRECT / IMPORT · QR' : 'DIRECT / IMPORT · URL',
          title: this.qrMode ? 'QR-код / Ссылка' : 'Ручной ввод ссылки',
          subtitle: this.qrMode
            ? 'QR: вставьте ссылку из сканера. Или введите vless://, vmess://, https:// вручную.'
            : 'Введите vless://, vmess://, trojan://, ss:// или https:// ссылку подписки.',
          onClose: this.onClose
        });
        ImportStatusBanner({ errorText: this.errorText, successText: this.successText });
        Text('ССЫЛКА ПОДПИСКИ')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.ink)
          .fontFamily('monospace')
          .margin({ top: 16, bottom: 7 });
        TextInput({ placeholder: 'vless://… или https://…', text: this.urlText })
          .height(52)
          .padding({ left: 13, right: 13 })
          .backgroundColor(DirectTheme.fieldFill)
          .border({ width: 1, color: DirectTheme.line })
          .fontSize(12)
          .fontColor(DirectTheme.ink)
          .margin({ bottom: 16 })
          .onChange((v: string) => { this.urlText = v; });
        ImportActionButton({
          label: 'ИМПОРТИРОВАТЬ',
          busy: this.busy,
          onTap: () => { void this.runImport(); }
        });
        if (this.successText.length > 0) {
          Row() {
            Text('ЗАКРЫТЬ')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
            Blank();
            Text('✕').fontSize(12).fontColor(DirectTheme.ink);
          }
          .width('100%')
          .height(52)
          .padding({ left: 15, right: 15 })
          .backgroundColor(DirectTheme.acid)
          .margin({ top: 10 })
          .onClick(() => {
            DirectHaptics.navigation();
            this.onClose();
          });
        }
        Blank().height(28);
      }.padding({ left: 20, right: 20, top: 18, bottom: 28 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

// ---------------------------------------------------------------------------
// ImportConfigText flow — raw JSON/YAML/URI-list
// ---------------------------------------------------------------------------

@Component
struct DirectImportConfigTextFlow {
  onClose: () => void = () => {};
  @State private configText: string = '';
  @State private errorText: string = '';
  @State private successText: string = '';
  @State private busy: boolean = false;

  private async runImport(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.successText = '';
    try {
      const name: string = await performImport(this.configText);
      this.successText = `✓ Импортировано: ${name}`;
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : `${err}`;
      this.errorText = msg;
    } finally {
      this.busy = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        ImportPageHeader({
          kicker: 'DIRECT / IMPORT · CONFIG',
          title: 'Вставить конфиг',
          subtitle: 'Вставьте текст sing-box JSON, Clash YAML или URI-список.',
          onClose: this.onClose
        });
        ImportStatusBanner({ errorText: this.errorText, successText: this.successText });
        Text('ТЕКСТ КОНФИГУРАЦИИ')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.ink)
          .fontFamily('monospace')
          .margin({ top: 16, bottom: 7 });
        TextArea({ placeholder: '{ "outbounds": […] }', text: this.configText })
          .height(180)
          .padding({ left: 13, right: 13, top: 10, bottom: 10 })
          .backgroundColor(DirectTheme.fieldFill)
          .border({ width: 1, color: DirectTheme.line })
          .fontSize(11)
          .fontColor(DirectTheme.ink)
          .fontFamily('monospace')
          .margin({ bottom: 16 })
          .onChange((v: string) => { this.configText = v; });
        ImportActionButton({
          label: 'ИМПОРТИРОВАТЬ',
          busy: this.busy,
          onTap: () => { void this.runImport(); }
        });
        if (this.successText.length > 0) {
          Row() {
            Text('ЗАКРЫТЬ')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
            Blank();
            Text('✕').fontSize(12).fontColor(DirectTheme.ink);
          }
          .width('100%')
          .height(52)
          .padding({ left: 15, right: 15 })
          .backgroundColor(DirectTheme.acid)
          .margin({ top: 10 })
          .onClick(() => {
            DirectHaptics.navigation();
            this.onClose();
          });
        }
        Blank().height(28);
      }.padding({ left: 20, right: 20, top: 18, bottom: 28 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

// ---------------------------------------------------------------------------
// ImportFile flow — document picker + paste fallback  (H)
// ---------------------------------------------------------------------------

@Component
struct DirectImportFileFlow {
  onClose: () => void = () => {};
  @State private fallbackText: string = '';
  @State private errorText: string = '';
  @State private successText: string = '';
  @State private busy: boolean = false;
  @State private showFallback: boolean = false;
  @State private pickerBusy: boolean = false;

  private async openFilePicker(): Promise<void> {
    if (this.pickerBusy) {
      return;
    }
    this.pickerBusy = true;
    this.errorText = '';
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const docPicker = new picker.DocumentViewPicker(ctx);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      opts.fileSuffixFilters = ['.json', '.yaml', '.yml', '.txt', '.conf', '.ovpn'];
      const uris = await docPicker.select(opts);
      if (uris.length === 0) {
        this.pickerBusy = false;
        return;
      }
      const uri = uris[0];
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const size = Number(stat.size);
      const readSize = Math.min(size, 1024 * 1024); // cap at 1 MB
      const buf = new ArrayBuffer(readSize);
      fs.readSync(file.fd, buf);
      fs.closeSync(file.fd);
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const text = decoder.decodeToString(new Uint8Array(buf));
      if (text.trim().length === 0) {
        this.errorText = 'Файл пуст';
        this.pickerBusy = false;
        return;
      }
      await this.runImportWithText(text);
    } catch (err) {
      const msg = err instanceof Error ? err.message : `${err}`;
      this.errorText = `Ошибка открытия файла: ${msg}`;
    } finally {
      this.pickerBusy = false;
    }
  }

  private async runImportWithText(text: string): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.successText = '';
    try {
      const name: string = await performImport(text);
      this.successText = `✓ Импортировано: ${name}`;
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : `${err}`;
      this.errorText = msg;
    } finally {
      this.busy = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        ImportPageHeader({
          kicker: 'DIRECT / IMPORT · FILE',
          title: 'Импорт файла',
          subtitle: 'JSON, Clash, WireGuard, ovpn.',
          onClose: this.onClose
        });
        ImportStatusBanner({ errorText: this.errorText, successText: this.successText });

        // File picker button
        Row() {
          Text(this.pickerBusy ? '…' : '▤  ВЫБРАТЬ ФАЙЛ')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace');
          Blank();
          Text('↗').fontSize(13).fontColor(DirectTheme.acid);
        }
        .width('100%')
        .height(52)
        .padding({ left: 15, right: 15 })
        .backgroundColor(DirectTheme.ink)
        .margin({ top: 16 })
        .onClick(() => {
          DirectHaptics.selection();
          void this.openFilePicker();
        });

        Text('JSON, Clash YAML, WireGuard, ovpn — до 1 МБ')
          .fontSize(10)
          .fontColor(DirectTheme.muted)
          .margin({ top: 6, bottom: 16 });

        // Paste fallback
        Row() {
          Text('+ ВСТАВИТЬ СОДЕРЖИМОЕ ФАЙЛА')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace');
          Blank();
          Text(this.showFallback ? '▲' : '▼')
            .fontSize(10)
            .fontColor(DirectTheme.acid);
        }
        .width('100%')
        .height(46)
        .padding({ left: 14, right: 14 })
        .backgroundColor(DirectTheme.ink)
        .onClick(() => {
          DirectHaptics.selection();
          this.showFallback = !this.showFallback;
        });

        if (this.showFallback) {
          TextArea({ placeholder: '{ "outbounds": […] }', text: this.fallbackText })
            .height(160)
            .padding({ left: 13, right: 13, top: 10, bottom: 10 })
            .backgroundColor(DirectTheme.fieldFill)
            .border({ width: 1, color: DirectTheme.line })
            .fontSize(11)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace')
            .margin({ top: 10, bottom: 12 })
            .onChange((v: string) => { this.fallbackText = v; });
          ImportActionButton({
            label: 'ИМПОРТИРОВАТЬ',
            busy: this.busy,
            onTap: () => { void this.runImportWithText(this.fallbackText); }
          });
        }

        if (this.successText.length > 0) {
          Row() {
            Text('ЗАКРЫТЬ')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
            Blank();
            Text('✕').fontSize(12).fontColor(DirectTheme.ink);
          }
          .width('100%')
          .height(52)
          .padding({ left: 15, right: 15 })
          .backgroundColor(DirectTheme.acid)
          .margin({ top: 10 })
          .onClick(() => {
            DirectHaptics.navigation();
            this.onClose();
          });
        }
        Blank().height(28);
      }.padding({ left: 20, right: 20, top: 18, bottom: 28 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

// ---------------------------------------------------------------------------
// Host — routes to the correct import flow
// ---------------------------------------------------------------------------

@Component
export struct DirectImportFlowHost {
  @Prop flow: DirectFlow = DirectFlow.ImportText;
  @Prop qrMode: boolean = false;
  onClose: () => void = () => {};

  build() {
    if (this.flow === DirectFlow.ImportClipboard) {
      DirectImportClipboardFlow({ onClose: this.onClose });
    } else if (this.flow === DirectFlow.ImportText) {
      DirectImportTextFlow({ onClose: this.onClose, qrMode: this.qrMode });
    } else if (this.flow === DirectFlow.ImportConfigText) {
      DirectImportConfigTextFlow({ onClose: this.onClose });
    } else {
      DirectImportFileFlow({ onClose: this.onClose });
    }
  }
}
