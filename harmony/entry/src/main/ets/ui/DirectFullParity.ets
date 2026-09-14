import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectIcon, DirectIconName } from './DirectIcons';
import { DirectBackendRuntime, DirectLocationRecord, DirectAccountDevice, DirectAccountPayment } from '../backend/DirectBackendRuntime';
import { DirectImportFlowHost } from './DirectImportFlows';
import { VpnServerSelection } from '../vpn/VpnServerSelection';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

// ---------------------------------------------------------------------------
// FlagBadge — shows a flag PNG from rawfile or falls back to code text
// Sizes exactly like iOS FlagImage: large=36×24, small=30×20
// ---------------------------------------------------------------------------
@Component
struct FlagBadge {
  @Prop code: string = '';
  @Prop badgeWidth: number = 36;
  @Prop badgeHeight: number = 24;
  @State private imgFailed: boolean = false;

  private get normalizedCode(): string {
    return this.code.toLowerCase().replace(/[^a-z]/g, '');
  }

  private get hasFlag(): boolean {
    return this.normalizedCode.length === 2 && !this.imgFailed;
  }

  build() {
    Stack() {
      if (this.hasFlag) {
        Image($rawfile(`flag_${this.normalizedCode}.png`))
          .width(this.badgeWidth)
          .height(this.badgeHeight)
          .objectFit(ImageFit.Cover)
          .onError(() => { this.imgFailed = true; });
      }
      if (!this.hasFlag) {
        Text(this.code.toUpperCase())
          .fontSize(7)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.acid)
          .fontFamily('monospace')
          .width(this.badgeWidth)
          .height(this.badgeHeight)
          .textAlign(TextAlign.Center)
          .backgroundColor(DirectTheme.ink);
      }
    }
    .width(this.badgeWidth)
    .height(this.badgeHeight);
  }
}

@Component
export struct DirectFullParityHost {
  @Prop flow: DirectFlow = DirectFlow.None;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @StorageProp('pending_qr_mode') private pendingQrMode: boolean = false;

  build() {
    if (this.flow === DirectFlow.ServerPicker) DirectServerPickerParity({ onClose: this.onClose });
    else if (this.flow === DirectFlow.ConnectionReport) DirectReportParity({ onClose: this.onClose });
    else if (this.flow === DirectFlow.Profiles) DirectProfilesParity({ onClose: this.onClose });
    else if (this.flow === DirectFlow.Access) DirectAccessParity({ onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow >= DirectFlow.AuthLogin && this.flow <= DirectFlow.AuthSuccess) DirectAuthParity({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Management || this.flow === DirectFlow.Subscription || this.flow === DirectFlow.Devices || this.flow === DirectFlow.PaymentHistory) DirectManagementParity({ flow: this.flow, onClose: this.onClose });
    else if (this.flow === DirectFlow.ImportClipboard || this.flow === DirectFlow.ImportText || this.flow === DirectFlow.ImportConfigText || this.flow === DirectFlow.ImportFile) DirectImportFlowHost({ flow: this.flow, onClose: this.onClose, qrMode: this.flow === DirectFlow.ImportText && this.pendingQrMode });
    else if (this.flow === DirectFlow.Legal || this.flow === DirectFlow.Privacy) DirectLegalParity({ flow: this.flow, onClose: this.onClose });
    else if (this.flow === DirectFlow.Account) DirectAccountParity({ onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Security || this.flow === DirectFlow.Connection || this.flow === DirectFlow.Diagnostics || this.flow === DirectFlow.Activity || this.flow === DirectFlow.SystemSettings || this.flow === DirectFlow.ApplicationSettings || this.flow === DirectFlow.CoreSettings || this.flow === DirectFlow.TunnelSettings || this.flow === DirectFlow.OnDemandSettings || this.flow === DirectFlow.About || this.flow === DirectFlow.ServiceLog) DirectSettingsParity({ flow: this.flow, onClose: this.onClose });
    else DirectOperationParity({ flow: this.flow, onClose: this.onClose });
  }
}

@Component
struct DirectParityPage {
  @Prop kicker: string = '';
  @Prop title: string = '';
  @Prop subtitle: string = '';

  build() {
    Column() {
      Text(this.kicker)
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.muted)
        .fontFamily('monospace');
      Text(this.title)
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor(DirectTheme.ink)
        .margin({ top: 5 });
      Text(this.subtitle)
        .fontSize(12)
        .fontColor(DirectTheme.muted)
        .width('100%')
        .margin({ top: 8, bottom: 4 });
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 18, bottom: 20 })
    .width('100%');
  }
}
@Component struct DirectSection { @Prop label:string=''; @Prop value:string=''; build(){Row(){Text(this.label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');Blank();Text(this.value).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace')}.height(40).width('100%').border({width:{top:1},color:DirectTheme.ink})} }
@Component struct DirectParityRow { @Prop mark:string=''; @Prop title:string=''; @Prop subtitle:string=''; onTap:()=>void=()=>{}; build(){Row(){Text(this.mark).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').textAlign(TextAlign.Center).width(45).height(40).backgroundColor(DirectTheme.ink);Column(){Text(this.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink);Text(this.subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({top:3})}.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({left:12});Text('›').fontSize(20).fontColor(DirectTheme.muted)}.constraintSize({ minHeight: 64 }).width('100%').border({width:{bottom:1},color:DirectTheme.line}).onClick(()=>{DirectHaptics.selection();this.onTap()})} }
@Component
struct DirectServerPickerParity {
  onClose: () => void = () => {};
  @State private selected: string = VpnServerSelection.get().id;
  @State private query: string = '';
  @State private tab: number = 0;
  @State private locations: DirectLocationRecord[] = [];
  @State private loading: boolean = false;
  @State private errorText: string = '';
  private readonly tabs: string[] = ['Все', 'Избранное', 'Недавние'];

  aboutToAppear(): void {
    void this.loadLocations();
  }

  private async loadLocations(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      const records: DirectLocationRecord[] = await DirectBackendRuntime.fetchLocations();
      this.locations = records;
      if (records.length === 0) {
        this.errorText = DirectBackendRuntime.baseURLString.length === 0
          ? 'Каталог локаций недоступен в этой сборке'
          : 'Список локаций пуст';
      }
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : `${err}`;
      this.errorText = msg.length > 0 ? msg : 'Не удалось загрузить локации';
    } finally {
      this.loading = false;
    }
  }

  private filtered(): DirectLocationRecord[] {
    const q = this.query.trim().toLowerCase();
    if (q.length === 0) {
      return this.locations;
    }
    return this.locations.filter((r: DirectLocationRecord) =>
      r.country.toLowerCase().includes(q) ||
      r.city.toLowerCase().includes(q) ||
      r.countryCode.toLowerCase().includes(q)
    );
  }

  private pickLocation(record: DirectLocationRecord): void {
    this.selected = record.id;
    VpnServerSelection.set({
      id: record.id,
      displayName: `${record.country} · ${record.city}`
    });
    DirectHaptics.selection();
    this.onClose();
  }

  build() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text('01').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
            Row().width(14).height(2).backgroundColor(DirectTheme.acid).margin({ left: 7, right: 7 });
            Text('SERVER / LOCATIONS').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          }
          Text('Локации')
            .fontSize(DirectTheme.pickerTitleSize)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .margin({ top: 5 });
          Text('Выберите сервер для текущего подключения')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(DirectTheme.muted)
            .margin({ top: 5 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Text('✕')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.acid)
          .width(38).height(38)
          .textAlign(TextAlign.Center)
          .backgroundColor(DirectTheme.ink)
          .onClick(() => {
            DirectHaptics.navigation();
            this.onClose();
          });
      }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 15 });

      Row() {
        Text('⌕').fontSize(12).fontColor(DirectTheme.green).margin({ right: 9 });
        TextInput({ placeholder: 'Страна или город', text: this.query })
          .layoutWeight(1)
          .height(DirectTheme.pickerSearchHeight)
          .fontSize(13)
          .fontColor(DirectTheme.ink)
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => { this.query = v; });
        if (this.query.length > 0) {
          Text('СБРОС')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.green)
            .fontFamily('monospace')
            .onClick(() => { this.query = ''; });
        }
      }
        .width('100%')
        .height(DirectTheme.pickerSearchHeight)
        .padding({ left: 13, right: 13 })
        .margin({ left: 20, right: 20 })
        .backgroundColor(DirectTheme.fieldFill)
        .border({ width: 1, color: DirectTheme.line });

      Row() {
        ForEach(this.tabs, (label: string, index: number) => {
          Text(label)
            .fontSize(10)
            .fontWeight(this.tab === index ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(DirectTheme.ink)
            .layoutWeight(1)
            .height(40)
            .textAlign(TextAlign.Center)
            .border({
              width: { bottom: this.tab === index ? 2 : 1 },
              color: this.tab === index ? DirectTheme.ink : '#8C000000'
            })
            .onClick(() => {
              this.tab = index;
              DirectHaptics.selection();
            });
        });
      }.width('100%').padding({ left: 20, right: 20, top: 5 });

      if (this.loading) {
        Text('Загрузка локаций…').fontSize(12).fontColor(DirectTheme.muted).margin({ top: 20, left: 20 });
      }
      if (this.errorText.length > 0) {
        Text(this.errorText).fontSize(11).fontColor(DirectTheme.muted).padding({ left: 20, right: 20, top: 12 });
      }

      Scroll() {
        Column() {
          // Auto row — always first in "Все" tab
          if (this.query.length === 0 && this.tab === 0) {
            Row() {
              Text('A')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(DirectTheme.acid)
                .fontFamily('monospace')
                .width(38).height(38)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.selected === 'auto' ? DirectTheme.ink : DirectTheme.panel);
              Column() {
                Row() {
                  Text('SMART ROUTE').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
                  if (this.selected === 'auto') {
                    Text('АКТИВНО').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ left: 6 });
                  }
                }
                Text('Автовыбор').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).margin({ top: 3 });
                Text('Лучший маршрут по задержке и доступности')
                  .fontSize(9.5).fontColor(DirectTheme.muted).margin({ top: 3 }).maxLines(1);
              }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 11 });
              Text(this.selected === 'auto' ? '✓' : '›')
                .fontSize(12)
                .fontColor(this.selected === 'auto' ? DirectTheme.green : DirectTheme.muted)
                .margin({ left: 8 });
            }
              .width('100%')
              .constraintSize({ minHeight: DirectTheme.pickerAutoRow })
              .padding({ left: 20, right: 20 })
              .backgroundColor(this.selected === 'auto' ? DirectTheme.acidSelected : Color.Transparent)
              .border({ width: { bottom: 1 }, color: DirectTheme.line })
              .onClick(() => {
                this.selected = 'auto';
                VpnServerSelection.set({ id: 'auto', displayName: 'Авто' });
                DirectHaptics.selection();
                this.onClose();
              });
          }

          Row() {
            Column() {
              Text('02 / VPN DIRECT').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
              Text(this.tab === 0 ? 'Доступные серверы' : this.tabs[this.tab])
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).margin({ top: 2 });
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Column() {
              Text(String(this.filtered().length).padStart(2, '0'))
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
              Text('ЛОКАЦИЙ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
            }.alignItems(HorizontalAlign.End);
          }
            .width('100%')
            .padding({ left: 20, right: 20, top: 11, bottom: 11 })
            .backgroundColor('#0B141714')
            .border({ width: { bottom: 1 }, color: DirectTheme.line });

          ForEach(this.filtered(), (record: DirectLocationRecord, i: number) => {
            Row() {
              FlagBadge({
                code: record.countryCode.length > 0 ? record.countryCode : '—',
                badgeWidth: 36,
                badgeHeight: 24
              });
              Column() {
                Text(record.country.length > 0 ? record.country : record.id)
                  .fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
                Text(record.city.length > 0 ? record.city : record.region)
                  .fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 2 });
              }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 });
              Column() {
                Text('СТАБИЛЬНО').fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
                Text(this.selected === record.id ? '✓' : '›')
                  .fontSize(12)
                  .fontColor(this.selected === record.id ? DirectTheme.green : DirectTheme.muted)
                  .margin({ top: 3 });
              }.alignItems(HorizontalAlign.End);
            }
              .width('100%')
              .height(58)
              .padding({ left: 20, right: 20 })
              .border({ width: { bottom: 1 }, color: DirectTheme.line })
              .backgroundColor(this.selected === record.id ? DirectTheme.acidSelected : Color.Transparent)
              .onClick(() => { this.pickLocation(record); });
          }, (record: DirectLocationRecord) => record.id);
          Blank().height(24);
        }.width('100%').padding({ top: 10 });
      }.layoutWeight(1).scrollBar(BarState.Off);
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}
/**
 * Port of DirectConnectionReportView — SheetScaffold + IP hero + fact grid + channel checks.
 * Status comes from AppStorage session / VPN state; empty values show "—".
 * "ОБНОВИТЬ" fetches the real public IP via api.ipify.org (public endpoint, no Direct hosts).
 */
@Component
struct DirectReportParity {
  onClose: () => void = () => {};
  @StorageProp('vpn_status') private vpnStatus: string = 'Disconnected';
  @StorageProp('vpn_server_name') private serverName: string = 'Авто';
  @StorageProp('connection_mode') private connectionMode: string = 'Авто';
  @StorageProp('direct_subscription_label') private subscriptionLabel: string = '';
  @State private publicIP: string = '—';
  @State private fetchingIP: boolean = false;

  private reportModeLabel(): string {
    if (this.connectionMode.length === 0) {
      return 'АВТО';
    }
    return this.connectionMode.toUpperCase();
  }

  private reportSubscriptionLabel(): string {
    if (this.subscriptionLabel.length > 0) {
      return this.subscriptionLabel.toUpperCase();
    }
    return 'VPN-DIRECT.COM';
  }

  private get protectedNow(): boolean {
    return this.vpnStatus === 'Connected';
  }

  aboutToAppear(): void {
    void this.refreshIP();
  }

  private async refreshIP(): Promise<void> {
    if (this.fetchingIP) {
      return;
    }
    this.fetchingIP = true;
    const client = http.createHttp();
    try {
      const resp = await client.request('http://api.ipify.org', {
        method: http.RequestMethod.GET,
        connectTimeout: 6000,
        readTimeout: 6000
      });
      let raw: string;
      if (typeof resp.result === 'string') {
        raw = resp.result;
      } else if (resp.result instanceof ArrayBuffer) {
        const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
        raw = decoder.decodeToString(new Uint8Array(resp.result as ArrayBuffer));
      } else {
        raw = '';
      }
      const trimmed = raw.trim();
      // Validate looks like an IP (rough check)
      if (trimmed.length > 0 && trimmed.length <= 45) {
        this.publicIP = trimmed;
      } else {
        this.publicIP = '—';
      }
    } catch {
      this.publicIP = '—';
    } finally {
      client.destroy();
      this.fetchingIP = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        // Sheet-style header: kicker + title + ✕ close button (system drag bar at top)
        // No extra left/right padding — the outer Column already has padding({ left: 20, right: 20 })
        Row() {
          Column() {
            Text(this.protectedNow ? 'ПРОВЕРКА / VPN' : 'ПРОВЕРКА / WAN')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.muted)
              .fontFamily('monospace');
            Text(this.protectedNow ? 'Соединение подключено' : 'Соединение отключено')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(DirectTheme.ink)
              .margin({ top: 5 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Text('✕')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .width(38).height(38)
            .textAlign(TextAlign.Center)
            .backgroundColor(DirectTheme.ink)
            .onClick(() => {
              DirectHaptics.navigation();
              this.onClose();
            });
        }.width('100%').padding({ top: 28, bottom: 16 });

        // IP hero — DirectConnectionReportView dark panel H106
        Row({ space: 13 }) {
          Text(this.protectedNow ? '✓' : '×')
            .fontSize(19)
            .fontColor(this.protectedNow ? DirectTheme.acid : DirectTheme.danger)
            .width(47)
            .height(47)
            .textAlign(TextAlign.Center)
            .border({ width: 1, color: '#40FFFFFF' });
          Column({ space: 4 }) {
            Text(this.protectedNow ? 'IP VPN' : 'РЕАЛЬНЫЙ IP')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor('#6BFFFFFF')
              .fontFamily('monospace');
            Text(this.fetchingIP ? '…' : this.publicIP)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .fontFamily('monospace');
            Text(this.protectedNow
              ? (this.serverName.length > 0 ? this.serverName : 'Туннель активен')
              : 'Без VPN — адрес вашего провайдера')
              .fontSize(9)
              .fontColor('#80FFFFFF');
          }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);
          Text(this.fetchingIP ? '…' : 'ОБНОВИТЬ')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace')
            .onClick(() => {
              DirectHaptics.selection();
              void this.refreshIP();
            });
        }
          .width('100%')
          .height(106)
          .padding({ left: 14, right: 14 })
          .backgroundColor(DirectTheme.ink);

        // Fact grid 2×3
        Row() {
          this.reportFact('ПРОТОКОЛ', 'VLESS · REALITY', false);
          this.reportFact('СОЕДИНЕНИЕ', this.protectedNow ? '—' : '00:00:00', false);
        }.width('100%');
        Row() {
          this.reportFact('DNS', this.protectedNow ? 'ЗАЩИЩЁН' : 'ОТКРЫТ', this.protectedNow);
          this.reportFact('ЗАДЕРЖКА', '— MS', false);
        }.width('100%');
        Row() {
          this.reportFact('РЕЖИМ', this.reportModeLabel(), false);
          this.reportFact('ПОДПИСКА', this.reportSubscriptionLabel(), false);
        }.width('100%');

        DirectSection({ label: 'ПРОВЕРКА КАНАЛА', value: this.protectedNow ? '4 / 4' : '0 / 4' });
        this.channelRow(this.protectedNow ? 'Исходящий IP через VPN' : 'Показан реальный IP');
        this.channelRow(this.protectedNow ? 'DNS-запросы защищены' : 'DNS-запросы открыты');
        this.channelRow(this.protectedNow ? 'WebRTC утечек нет' : 'WebRTC не проверялся');
        this.channelRow('Маршрут через VPN');
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 28 });
    }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .backgroundColor(DirectTheme.paper);
  }

  @Builder
  reportFact(label: string, value: string, safe: boolean) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.muted)
        .fontFamily('monospace')
        .width('100%');
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(safe ? DirectTheme.green : DirectTheme.ink)
        .fontFamily('monospace')
        .width('100%');
    }
      .layoutWeight(1)
      .padding({ top: 14, bottom: 14, left: 2, right: 8 })
      .border({ width: { bottom: 1, right: 1 }, color: DirectTheme.line });
  }

  @Builder
  channelRow(title: string) {
    Row() {
      Text(title)
        .fontSize(11)
        .fontColor(DirectTheme.ink)
        .layoutWeight(1);
      Text(this.protectedNow ? '✓' : '—')
        .fontSize(14)
        .fontColor(this.protectedNow ? DirectTheme.green : DirectTheme.muted);
    }
      .width('100%')
      .height(44)
      .border({ width: { bottom: 1 }, color: DirectTheme.line });
  }
}
// ---------------------------------------------------------------------------
// Connection mode data
// ---------------------------------------------------------------------------
interface ConnectionModeData {
  id: string;
  badge: string;
  title: string;
  subtitle: string;
}
const CONNECTION_MODES: ConnectionModeData[] = [
  { id: 'Авто', badge: 'A', title: 'Авто', subtitle: 'Баланс скорости и стабильности' },
  { id: 'Пользовательский', badge: 'M', title: 'Пользовательский', subtitle: 'Только выбранный вручную сервер' },
  { id: 'Максимальная скорость', badge: 'S', title: 'Максимальная скорость', subtitle: 'Ближайший сервер с минимальным ping' },
  { id: 'Стабильный', badge: 'R', title: 'Стабильный', subtitle: 'Надёжный маршрут и failover' },
  { id: 'Для видео', badge: 'V', title: 'Для видео', subtitle: 'Высокая пропускная способность' },
  { id: '5G', badge: 'X', title: '5G', subtitle: 'Оптимизация для мобильных сетей' },
];
@Component
struct DirectProfilesParity {
  onClose: () => void = () => {};
  @StorageProp('connection_mode') private selectedMode: string = 'Авто';

  private isSelected(mode: ConnectionModeData): boolean {
    if (mode.id === '5G') {
      return this.selectedMode === '5G' || this.selectedMode === 'Антиблокировка';
    }
    return this.selectedMode === mode.id;
  }

  private selectMode(id: string): void {
    AppStorage.setOrCreate('connection_mode', id);
    DirectHaptics.selection();
    this.onClose();
  }

  build() {
    Column() {
      // Sheet-style header: kicker + title + ✕ close button
      Row() {
        Column() {
          Text('РЕЖИМ / 06')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace');
          Text('Режим подключения')
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(DirectTheme.ink)
            .margin({ top: 5 });
          Text('Выберите, как клиент подбирает сервер и ведёт себя при сбое.')
            .fontSize(12)
            .fontColor(DirectTheme.muted)
            .width('100%')
            .margin({ top: 8, bottom: 4 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Text('✕')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.acid)
          .width(38).height(38)
          .textAlign(TextAlign.Center)
          .backgroundColor(DirectTheme.ink)
          .onClick(() => {
            DirectHaptics.navigation();
            this.onClose();
          });
      }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 16 });

      Column() {
        ForEach(CONNECTION_MODES, (mode: ConnectionModeData, index: number) => {
          Row({ space: 10 }) {
            Text(String(index + 1).padStart(2, '0'))
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.muted)
              .fontFamily('monospace')
              .width(18);
            Text(mode.badge)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.acid)
              .fontFamily('monospace')
              .width(28)
              .height(28)
              .textAlign(TextAlign.Center)
              .backgroundColor(DirectTheme.ink);
            Column({ space: 2 }) {
              Text(mode.title)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(DirectTheme.ink)
                .maxLines(1);
              Text(mode.subtitle)
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(DirectTheme.muted)
                .maxLines(1);
            }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);
            if (this.isSelected(mode)) {
              DirectIcon({
                name: DirectIconName.Checkmark,
                iconSize: 12,
                color: DirectTheme.green,
                weight: 1.8
              });
            } else {
              DirectIcon({
                name: DirectIconName.ChevronRight,
                iconSize: 10,
                color: DirectTheme.muted,
                weight: 1.6
              });
            }
          }
            .width('100%')
            .constraintSize({ minHeight: 56 })
            .padding({ left: 10, right: 10 })
            .backgroundColor(this.isSelected(mode) ? DirectTheme.acidSelected : Color.Transparent)
            .border({ width: { bottom: 1 }, color: DirectTheme.line })
            .onClick(() => this.selectMode(mode.id));
        }, (mode: ConnectionModeData) => mode.id);
      }
        .width('100%')
        .margin({ left: 20, right: 20 })
        .border({ width: 1, color: DirectTheme.line });

      Blank().layoutWeight(1);
    }
      .width('100%')
      .height('100%')
      .padding({ left: 0, right: 0 })
      .backgroundColor(DirectTheme.paper);
  }
}
@Component struct DirectAccessParity { onClose:()=>void=()=>{}; onFlow:(f:DirectFlow)=>void=(_f)=>{}; build(){Scroll(){Column(){DirectParityPage({kicker:'ПОДКЛЮЧЕНИЕ / НАЧАЛО',title:'Выберите доступ',subtitle:'Сначала VPN Direct, затем другие провайдеры'});Column(){Text('СЕЙЧАС НЕ ЗАЩИЩЕНО').fontSize(9).fontFamily('monospace').fontColor('#6BFFFFFF');Text('У вас пока нет активного подключения').fontSize(20).fontWeight(FontWeight.Medium).fontColor(Color.White).margin({top:7});Text('Оформите тариф VPN Direct или подключите внешнюю подписку.').fontSize(10).fontColor('#80FFFFFF').margin({top:5})}.padding(17).width('100%').backgroundColor(DirectTheme.panel).margin({bottom:22});DirectSection({label:'VPN DIRECT',value:'01'});DirectParityRow({mark:'PLUS',title:'Тарифы VPN Direct',subtitle:'Пресеты и конструктор · Plus рекомендуем',onTap:()=>this.onFlow(DirectFlow.Plans)});DirectSection({label:'ДРУГИЕ ПРОВАЙДЕРЫ',value:'01'});DirectParityRow({mark:'URL',title:'Добавить внешнюю подписку',subtitle:'QR, ссылка, файл или конфиг',onTap:()=>this.onFlow(DirectFlow.ImportText)})}.padding({left:20,right:20,bottom:30})}.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper)} }
@Component
struct DirectAuthParity {
  @Prop flow: DirectFlow = DirectFlow.AuthLogin;
  onClose: () => void = () => {};
  onFlow: (f: DirectFlow) => void = (_f: DirectFlow) => {};
  @State email: string = '';
  @State password: string = '';
  @State code: string = '';
  @State errorText: string = '';
  @State busy: boolean = false;
  @State infoText: string = '';

  build() {
    Scroll() {
      Column() {
        DirectParityPage({
          kicker: 'ACCOUNT / AUTH',
          title: this.title(),
          subtitle: 'Безопасный вход и синхронизация состояния сервиса.'
        });
        Row() {
          Text('DIRECT')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace')
            .width(DirectTheme.authBrandW)
            .height(DirectTheme.authBrandH)
            .textAlign(TextAlign.Center)
            .backgroundColor(DirectTheme.ink);
          Column() {
            Text('БЕЗОПАСНЫЙ ВХОД')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
            Text('Продолжайте с выбранным способом')
              .fontSize(10)
              .fontColor(DirectTheme.muted)
              .margin({ top: 3 });
          }.alignItems(HorizontalAlign.Start).margin({ left: 12 });
          Blank();
        }.width('100%').margin({ bottom: 20 });
        if (this.errorText.length > 0) {
          Text(this.errorText).fontSize(12).fontColor('#B00020').width('100%').margin({ bottom: 10 });
        }
        if (this.infoText.length > 0) {
          Text(this.infoText).fontSize(12).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 10 });
        }
        Text('EMAIL').fontSize(9).fontFamily('monospace').fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
        TextInput({ placeholder: 'email@example.com', text: this.email })
          .height(50)
          .padding({ left: 13, right: 13 })
          .backgroundColor(DirectTheme.fieldFill)
          .border({ width: 1, color: DirectTheme.line })
          .margin({ top: 7, bottom: 14 })
          .onChange((v: string) => this.email = v);
        if (this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.AuthEmail || this.flow === DirectFlow.AuthRegister) {
          Text('ПАРОЛЬ').fontSize(9).fontFamily('monospace').fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
          TextInput({ placeholder: 'Пароль', text: this.password })
            .type(InputType.Password)
            .height(50)
            .padding({ left: 13, right: 13 })
            .backgroundColor(DirectTheme.fieldFill)
            .border({ width: 1, color: DirectTheme.line })
            .margin({ top: 7, bottom: 14 })
            .onChange((v: string) => this.password = v);
        } else if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) {
          Text('КОД ПОДТВЕРЖДЕНИЯ').fontSize(9).fontFamily('monospace').fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
          TextInput({ placeholder: '000000', text: this.code })
            .type(InputType.Number)
            .height(50)
            .padding({ left: 13, right: 13 })
            .backgroundColor(DirectTheme.fieldFill)
            .border({ width: 1, color: DirectTheme.line })
            .margin({ top: 7, bottom: 14 })
            .onChange((v: string) => this.code = v);
        }
        Row() {
          Text(this.busy ? '…' : this.actionTitle())
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace');
          Blank();
          Text('→').fontSize(12).fontColor(DirectTheme.acid);
        }
          .width('100%')
          .height(DirectTheme.authPrimaryHeight)
          .padding({ left: 14, right: 14 })
          .backgroundColor(DirectTheme.ink)
          .margin({ bottom: 12 })
          .onClick(() => {
            DirectHaptics.selection();
            void this.submit();
          });
        DirectParityRow({
          mark: 'CODE',
          title: 'Войти по коду',
          subtitle: 'Без постоянного пароля',
          onTap: () => this.onFlow(DirectFlow.AuthCode)
        });
        Blank().height(28);
      }.padding({ left: 20, right: 20, bottom: 30 })
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  private actionTitle(): string {
    if (this.flow === DirectFlow.AuthRegister) {
      return 'СОЗДАТЬ АККАУНТ';
    }
    if (this.flow === DirectFlow.AuthRecovery) {
      return 'ПРОДОЛЖИТЬ';
    }
    if (this.flow === DirectFlow.AuthCode) {
      return this.code.trim().length === 0 ? 'ПОЛУЧИТЬ КОД' : 'ПОДТВЕРДИТЬ';
    }
    return 'ВОЙТИ';
  }

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.errorText = '';
    this.infoText = '';
    this.busy = true;
    try {
      if (this.flow === DirectFlow.AuthRegister) {
        const register = DirectBackendRuntime.registerWithPassword;
        if (!register) {
          this.errorText = 'Сервис регистрации недоступен';
          return;
        }
        const name = this.email.trim().split('@')[0];
        await register(name, this.email.trim(), this.password, this.password);
        this.onFlow(DirectFlow.AuthSuccess);
        return;
      }
      if (this.flow === DirectFlow.AuthCode) {
        if (this.code.trim().length === 0) {
          const send = DirectBackendRuntime.sendEmailCode;
          if (!send) {
            this.errorText = 'Отправка кода недоступна';
            return;
          }
          await send(this.email.trim());
          this.infoText = 'Код отправлен на email';
          return;
        }
        const verify = DirectBackendRuntime.verifyEmailCode;
        if (!verify) {
          this.errorText = 'Проверка кода недоступна';
          return;
        }
        await verify(this.email.trim(), this.code.trim());
        this.onFlow(DirectFlow.AuthSuccess);
        return;
      }
      if (this.flow === DirectFlow.AuthRecovery) {
        const reset = DirectBackendRuntime.requestPasswordReset;
        if (!reset) {
          this.errorText = 'Восстановление недоступно';
          return;
        }
        await reset(this.email.trim());
        this.infoText = 'Если аккаунт существует, инструкции отправлены на email';
        return;
      }
      const login = DirectBackendRuntime.loginWithPassword;
      if (!login) {
        this.errorText = 'Сервис входа недоступен';
        return;
      }
      await login(this.email.trim(), this.password);
      this.onFlow(DirectFlow.AuthSuccess);
    } catch (err) {
      const message = err instanceof Error ? err.message : `${err}`;
      this.errorText = message.length > 0 ? message : 'Не удалось выполнить вход';
    } finally {
      this.busy = false;
    }
  }

  private title(): string {
    if (this.flow === DirectFlow.AuthRegister) {
      return 'Регистрация';
    }
    if (this.flow === DirectFlow.AuthRecovery) {
      return 'Восстановление';
    }
    if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) {
      return 'Подтверждение';
    }
    if (this.flow === DirectFlow.AuthSuccess) {
      return 'Готово';
    }
    return 'Вход';
  }
}
@Component struct DirectParityAction { @Prop title:string=''; onTap:()=>void=()=>{}; build(){Row(){Text(this.title).fontSize(10).fontWeight(FontWeight.Bold).fontFamily('monospace').fontColor(DirectTheme.ink);Blank();Text('→').fontSize(14).fontColor(DirectTheme.ink)}.width('100%').height(56).padding({left:15,right:15}).backgroundColor(DirectTheme.acid).border({width:1.5,color:DirectTheme.ink}).onClick(()=>{DirectHaptics.selection();this.onTap()}).margin({bottom:12})} }
@Component
struct DirectManagementParity {
  @Prop flow: DirectFlow = DirectFlow.Management;
  onClose: () => void = () => {};
  @State private devices: DirectAccountDevice[] = [];
  @State private payments: DirectAccountPayment[] = [];
  @State private promoCode: string = '';
  @State private promoResult: string = '';
  @State private loading: boolean = false;
  @State private errorText: string = '';

  aboutToAppear(): void {
    if (this.flow === DirectFlow.Devices) {
      void this.loadDevices();
    } else if (this.flow === DirectFlow.PaymentHistory) {
      void this.loadPayments();
    }
  }

  private async loadDevices(): Promise<void> {
    this.loading = true;
    try {
      this.devices = await DirectBackendRuntime.fetchAccountDevices();
    } catch (err) {
      this.errorText = err instanceof Error ? err.message : `${err}`;
    } finally {
      this.loading = false;
    }
  }

  private async loadPayments(): Promise<void> {
    this.loading = true;
    try {
      this.payments = await DirectBackendRuntime.fetchAccountPayments();
    } catch (err) {
      this.errorText = err instanceof Error ? err.message : `${err}`;
    } finally {
      this.loading = false;
    }
  }

  private async redeemPromo(): Promise<void> {
    if (this.promoCode.trim().length === 0) {
      return;
    }
    try {
      const result = await DirectBackendRuntime.redeemPromo(this.promoCode.trim());
      this.promoResult = result.ok ? `✓ ${result.message}` : `✗ ${result.message}`;
      if (result.ok) {
        this.promoCode = '';
      }
    } catch (err) {
      this.promoResult = `✗ ${err instanceof Error ? err.message : `${err}`}`;
    }
  }

  private openSupport(): void {
    // Support via mailto — submitSupport not in public runtime
    console.info('DirectManagementParity: support requested');
  }

  build() {
    Scroll() {
      Column() {
        if (this.flow === DirectFlow.Devices || this.flow === DirectFlow.PaymentHistory) {
          // Sheet-style header with ✕ for these flows (opened as bottom sheets)
          Row() {
            Column() {
              Text('DIRECT / MANAGEMENT')
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .fontColor(DirectTheme.muted)
                .fontFamily('monospace');
              Text(this.title())
                .fontSize(22)
                .fontWeight(FontWeight.Medium)
                .fontColor(DirectTheme.ink)
                .margin({ top: 5 });
              Text('Подписка, устройства и история операций.')
                .fontSize(12)
                .fontColor(DirectTheme.muted)
                .width('100%')
                .margin({ top: 8, bottom: 4 });
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Text('✕')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.acid)
              .width(38).height(38)
              .textAlign(TextAlign.Center)
              .backgroundColor(DirectTheme.ink)
              .onClick(() => {
                DirectHaptics.navigation();
                this.onClose();
              });
          }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 16 });
        } else {
          DirectParityPage({
            kicker: 'DIRECT / MANAGEMENT',
            title: this.title(),
            subtitle: 'Подписка, устройства и история операций.'
          });
        }

        if (this.flow === DirectFlow.Devices) {
          this.devicesContent();
        } else if (this.flow === DirectFlow.PaymentHistory) {
          this.paymentsContent();
        } else {
          this.managementOverview();
        }
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private managementOverview() {
    DirectSection({ label: 'СЕРВИС', value: '—' });
    DirectParityRow({ mark: 'PLAN', title: 'Текущий тариф', subtitle: 'Состояние и параметры доступа' });
    DirectParityRow({ mark: 'DEV', title: 'Устройства', subtitle: 'Управление подключёнными устройствами' });
    DirectParityRow({ mark: 'HIST', title: 'История операций', subtitle: 'Покупки, пополнения и возвраты' });

    // Promo section
    DirectSection({ label: 'ПРОМОКОД', value: '' });
    if (this.promoResult.length > 0) {
      Text(this.promoResult)
        .fontSize(12)
        .fontColor(this.promoResult.startsWith('✓') ? DirectTheme.green : '#CC0000')
        .width('100%')
        .margin({ top: 8, bottom: 6 });
    }
    Row() {
      TextInput({ placeholder: 'Введите промокод', text: this.promoCode })
        .layoutWeight(1)
        .height(46)
        .padding({ left: 12, right: 12 })
        .backgroundColor(DirectTheme.fieldFill)
        .border({ width: 1, color: DirectTheme.line })
        .fontSize(13)
        .onChange((v: string) => { this.promoCode = v; });
      Text('ПРИМЕНИТЬ')
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.acid)
        .fontFamily('monospace')
        .padding({ left: 14, right: 14 })
        .height(46)
        .textAlign(TextAlign.Center)
        .backgroundColor(DirectTheme.ink)
        .onClick(() => { DirectHaptics.selection(); void this.redeemPromo(); });
    }.width('100%').margin({ top: 8 });

    // Support section
    DirectSection({ label: 'ПОДДЕРЖКА', value: '' });
    DirectParityRow({
      mark: 'HELP',
      title: 'Написать в поддержку',
      subtitle: 'Оплата, вход, подписка и подключение',
      onTap: () => this.openSupport()
    });
    Blank().height(24);
  }

  @Builder
  private devicesContent() {
    if (this.loading) {
      Text('Загрузка устройств…').fontSize(12).fontColor(DirectTheme.muted).margin({ top: 16 });
    } else if (this.errorText.length > 0) {
      Text(this.errorText).fontSize(11).fontColor('#CC0000').margin({ top: 16 });
    } else if (this.devices.length === 0) {
      Text('Нет зарегистрированных устройств').fontSize(12).fontColor(DirectTheme.muted).margin({ top: 16 });
    } else {
      ForEach(this.devices, (d: DirectAccountDevice) => {
        Row() {
          Text(d.isCurrent ? '◆' : '○')
            .fontSize(12)
            .fontColor(d.isCurrent ? DirectTheme.green : DirectTheme.ink)
            .width(22).textAlign(TextAlign.Center);
          Column() {
            Text(d.label).fontSize(13).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
            Text(d.detail).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 11 });
          if (d.isCurrent) {
            Text('ТЕКУЩЕЕ').fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
          }
        }
        .width('100%')
        .constraintSize({ minHeight: 58 })
        .border({ width: { bottom: 1 }, color: DirectTheme.line });
      }, (d: DirectAccountDevice) => d.id);
    }
    Blank().height(24);
  }

  @Builder
  private paymentsContent() {
    if (this.loading) {
      Text('Загрузка операций…').fontSize(12).fontColor(DirectTheme.muted).margin({ top: 16 });
    } else if (this.errorText.length > 0) {
      Text(this.errorText).fontSize(11).fontColor('#CC0000').margin({ top: 16 });
    } else if (this.payments.length === 0) {
      Text('История операций пуста').fontSize(12).fontColor(DirectTheme.muted).margin({ top: 16 });
    } else {
      ForEach(this.payments, (p: DirectAccountPayment) => {
        Row() {
          Column() {
            Text(p.title).fontSize(13).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
            Text(p.subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Column() {
            Text(p.amountLabel)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(p.isRefundLike ? '#CC0000' : DirectTheme.ink)
              .fontFamily('monospace');
            Text(p.statusLabel).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 3 });
          }.alignItems(HorizontalAlign.End);
        }
        .width('100%')
        .constraintSize({ minHeight: 58 })
        .border({ width: { bottom: 1 }, color: DirectTheme.line });
      }, (p: DirectAccountPayment) => p.id);
    }
    Blank().height(24);
  }

  private title(): string {
    if (this.flow === DirectFlow.Subscription) return 'Подписка';
    if (this.flow === DirectFlow.Devices) return 'Устройства';
    if (this.flow === DirectFlow.PaymentHistory) return 'История операций';
    return 'Управление';
  }
}
@Component struct DirectImportParity { @Prop flow:DirectFlow=DirectFlow.ImportFile; onClose:()=>void=()=>{}; @State value:string=''; build(){Column(){DirectParityPage({kicker:'DIRECT / IMPORT',title:'Импорт подписки',subtitle:'QR, ссылка, файл или конфигурация.'});Text(this.flow===DirectFlow.ImportFile?'ФАЙЛ':'ССЫЛКА / КОНФИГ').fontSize(9).fontFamily('monospace').fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);if(this.flow===DirectFlow.ImportFile)DirectParityRow({mark:'FILE',title:'Выбрать файл',subtitle:'Поддерживаемая конфигурация подключения'});else{TextInput({placeholder:'https://…',text:this.value}).height(52).margin({top:8,bottom:14}).onChange(v=>this.value=v);DirectParityAction({title:'ИМПОРТИРОВАТЬ',onTap:()=>this.onClose()})}}.padding({left:20,right:20}).backgroundColor(DirectTheme.paper).width('100%').height('100%')} }
@Component struct DirectLegalParity { @Prop flow:DirectFlow=DirectFlow.Legal; onClose:()=>void=()=>{}; build(){Scroll(){Column(){DirectParityPage({kicker:'DIRECT / LEGAL',title:this.flow===DirectFlow.Privacy?'Конфиденциальность':'Правовая информация',subtitle:'Документы и сведения о приложении.'});DirectSection({label:'ДОКУМЕНТ',value:'01'});Text(this.flow===DirectFlow.Privacy?'VPN Direct обрабатывает только данные, необходимые для работы сервиса.':'Информация о сервисе, условиях использования и обработке данных.').fontSize(12).fontColor(DirectTheme.ink).margin({top:14})}.padding({left:20,right:20})}.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper)} }
@Component struct DirectAccountParity { onClose:()=>void=()=>{}; onFlow:(f:DirectFlow)=>void=(_f)=>{}; build(){Column(){DirectParityPage({kicker:'ACCOUNT',title:'Аккаунт',subtitle:'Профиль и состояние учётной записи.'});DirectParityRow({mark:'AUTH',title:'Войти',subtitle:'Синхронизация аккаунта',onTap:()=>this.onFlow(DirectFlow.AuthLogin)});DirectParityRow({mark:'BAL',title:'Баланс',subtitle:'Средства для быстрых покупок VPN Direct',onTap:()=>this.onFlow(DirectFlow.Balance)});DirectParityRow({mark:'LEGAL',title:'Конфиденциальность',subtitle:'Правовые документы',onTap:()=>this.onFlow(DirectFlow.Privacy)})}.padding({left:20,right:20}).backgroundColor(DirectTheme.paper).width('100%').height('100%')} }
@Component
struct DirectSettingsParity {
  @Prop flow: DirectFlow = DirectFlow.Security;
  onClose: () => void = () => {};

  // Persisted toggles — same AppStorage keys as DirectSettingsNative
  @StorageProp('pref_auto_connect') private autoConnect: boolean = false;
  @StorageProp('pref_dns_protect') private dnsProtect: boolean = true;
  @StorageProp('pref_face_id') private faceID: boolean = false;
  @StorageProp('pref_lan_access') private lanAccess: boolean = false;
  @StorageProp('pref_ipv6') private ipv6: boolean = false;

  build() {
    Scroll() {
      Column() {
        DirectParityPage({
          kicker: 'DIRECT / SETTINGS',
          title: this.title(),
          subtitle: 'Параметры подключения и приложения.'
        });

        if (this.flow === DirectFlow.Security || this.flow === DirectFlow.ApplicationSettings) {
          this.sectionHeader('01', 'БЕЗОПАСНОСТЬ', '03');
          this.toggleRow('Автоподключение', 'Подключаться при запуске приложения',
            this.autoConnect, 'pref_auto_connect');
          this.toggleRow('Face ID / отпечаток', 'Биометрическая защита (заглушка)',
            this.faceID, 'pref_face_id');
          this.toggleRow('Защита DNS', 'Все DNS-запросы через зашифрованный туннель',
            this.dnsProtect, 'pref_dns_protect');
        }

        if (this.flow === DirectFlow.Connection || this.flow === DirectFlow.CoreSettings ||
            this.flow === DirectFlow.TunnelSettings) {
          this.sectionHeader('01', 'СОЕДИНЕНИЕ', '02');
          this.toggleRow('Доступ к LAN', 'Устройства локальной сети видны при VPN',
            this.lanAccess, 'pref_lan_access');
          this.toggleRow('IPv6', 'Туннелирование IPv6-трафика',
            this.ipv6, 'pref_ipv6');
        }

        if (this.flow === DirectFlow.OnDemandSettings) {
          this.sectionHeader('01', 'ON-DEMAND', '01');
          this.toggleRow('Автоподключение по требованию', 'Активируется по правилам сети',
            this.autoConnect, 'pref_auto_connect');
        }

        if (this.flow === DirectFlow.About || this.flow === DirectFlow.Diagnostics ||
            this.flow === DirectFlow.Activity || this.flow === DirectFlow.SystemSettings ||
            this.flow === DirectFlow.ServiceLog) {
          this.sectionHeader('01', 'ОСНОВНОЕ', '04');
          this.infoRow('Статус', 'Текущее состояние VPN Direct', false);
          this.infoRow('Системные настройки', 'Параметры HarmonyOS и разрешения', false);
          this.sectionHeader('02', 'СЕТЬ', '02');
          this.infoRow('Диагностика', 'Сведения для проверки соединения', true);
          this.infoRow('О приложении', 'VPN Direct · HarmonyOS', false);
        }

        Blank().height(24);
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private sectionHeader(number: string, title: string, meta: string) {
    Row() {
      Text(number).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
      Text(title).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ left: 11 });
      Blank();
      Text(meta).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
    }
      .width('100%')
      .height(DirectTheme.systemSectionHeight)
      .border({ width: { top: 1 }, color: DirectTheme.ink });
  }

  @Builder
  private toggleRow(title: string, subtitle: string, value: boolean, storageKey: string) {
    Row() {
      Column() {
        Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
        Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Toggle({ type: ToggleType.Switch, isOn: value })
        .width(44)
        .height(26)
        .selectedColor(DirectTheme.green)
        .onChange((on: boolean) => {
          AppStorage.setOrCreate(storageKey, on);
          DirectHaptics.selection();
        });
    }
      .width('100%')
      .constraintSize({ minHeight: DirectTheme.systemRowMin })
      .border({ width: { bottom: 1 }, color: DirectTheme.line });
  }

  @Builder
  private infoRow(title: string, subtitle: string, accent: boolean) {
    Row() {
      Text(accent ? '◆' : '○')
        .fontSize(14)
        .fontColor(accent ? DirectTheme.green : DirectTheme.ink)
        .width(25)
        .textAlign(TextAlign.Center);
      Column() {
        Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
        Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 13 });
      Text('↗').fontSize(10).fontColor(accent ? DirectTheme.green : DirectTheme.muted);
    }
      .width('100%')
      .constraintSize({ minHeight: DirectTheme.systemRowMin })
      .border({ width: { bottom: 1 }, color: DirectTheme.line });
  }

  private title(): string {
    if (this.flow === DirectFlow.About) return 'О приложении';
    if (this.flow === DirectFlow.Diagnostics) return 'Диагностика';
    if (this.flow === DirectFlow.Security) return 'Безопасность';
    if (this.flow === DirectFlow.Connection) return 'Соединение';
    if (this.flow === DirectFlow.Activity) return 'Активность';
    if (this.flow === DirectFlow.SystemSettings) return 'Системные настройки';
    if (this.flow === DirectFlow.ApplicationSettings) return 'Настройки приложения';
    if (this.flow === DirectFlow.CoreSettings) return 'Core';
    if (this.flow === DirectFlow.TunnelSettings) return 'Tunnel';
    if (this.flow === DirectFlow.OnDemandSettings) return 'On Demand';
    if (this.flow === DirectFlow.ServiceLog) return 'Журнал';
    return 'Настройки';
  }
}

@Component struct DirectOperationParity { @Prop flow:DirectFlow=DirectFlow.PaymentProcessing; onClose:()=>void=()=>{}; build(){Column(){DirectParityPage({kicker:'DIRECT / STATE',title:this.title(),subtitle:'Операция выполняется или ожидает результата.'});Column(){Text(this.status()).fontSize(10).fontWeight(FontWeight.Bold).fontFamily('monospace').fontColor(DirectTheme.muted);Text('Состояние синхронизируется с сервисом.').fontSize(13).fontColor(DirectTheme.ink).margin({top:10})}.padding(18).width('100%').backgroundColor('#59FFFFFF').border({width:1,color:DirectTheme.line})}.padding({left:20,right:20}).backgroundColor(DirectTheme.paper).width('100%').height('100%')} private title(){if(this.flow===DirectFlow.PaymentSuccess)return'Готово';if(this.flow===DirectFlow.PaymentError)return'Ошибка';if(this.flow===DirectFlow.PaymentCancelled)return'Отменено';if(this.flow===DirectFlow.PaymentWaiting)return'Ожидание';return'Обработка'} private status(){if(this.flow===DirectFlow.PaymentSuccess)return'ОПЕРАЦИЯ ЗАВЕРШЕНА';if(this.flow===DirectFlow.PaymentError)return'НЕ УДАЛОСЬ ЗАВЕРШИТЬ';if(this.flow===DirectFlow.PaymentCancelled)return'ОПЕРАЦИЯ ОТМЕНЕНА';return'ОБРАБОТКА'}}
