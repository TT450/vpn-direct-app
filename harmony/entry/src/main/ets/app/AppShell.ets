import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics } from '../ui/Haptics';
import { DirectIcon, DirectIconName } from '../ui/DirectIcons';
import { HomePage } from '../pages/HomePage';
import { LocationsPage } from '../pages/LocationsPage';
import { ManagementPage } from '../pages/ManagementPage';
import { ProfilePage } from '../pages/ProfilePage';
import { DirectFlow, DirectFlowHost } from '../ui/DirectFlows';
import { DirectNativeFlowHost } from '../ui/DirectNativeFlows';
import { DirectPlanParityHost } from '../ui/DirectPlanParity';
import { DirectPrivacyDisclosure } from '../ui/DirectPrivacyDisclosure';

export enum DirectTab { Home = 0, Locations = 1, Management = 2, Profile = 3 }

interface AddMenuAction { index: string; title: string; detail: string; flow: DirectFlow | null; }

@Component
export struct AppShell {
  @State private selectedTab: DirectTab = DirectTab.Home;
  @State private activeFlow: DirectFlow = DirectFlow.None;
  @State private sheetOpen: boolean = false;
  @State private showPrivacyDisclosure: boolean = false;
  @State private privacyAccepted: boolean = false;
  @State private isMenuOpen: boolean = false;
  @Prop status: string = 'Disconnected';
  @Prop serverName: string = 'Авто';
  onToggle: () => void = () => {};
  @StorageProp('direct_import_ts') @Watch('onImportSuccess') private importTs: number = 0;

  onImportSuccess(): void {
    this.sheetOpen = false;
    this.activeFlow = DirectFlow.None;
    this.selectedTab = DirectTab.Management;
    this.isMenuOpen = false;
  }

  private isSheetFlow(flow: DirectFlow): boolean {
    return flow === DirectFlow.ServerPicker ||
      flow === DirectFlow.ConnectionReport ||
      flow === DirectFlow.Profiles ||
      flow === DirectFlow.Subscription ||
      flow === DirectFlow.Balance ||
      flow === DirectFlow.BalanceTopUp ||
      flow === DirectFlow.Devices ||
      flow === DirectFlow.PaymentHistory;
  }

  private openSheet(flow: DirectFlow): void { this.activeFlow = flow; this.sheetOpen = true; DirectHaptics.navigation(); }
  private closeSheet(): void { this.sheetOpen = false; this.activeFlow = DirectFlow.None; }

  private readonly addMenuActions: AddMenuAction[] = [
    { index: '01', title: 'Отсканировать QR', detail: 'Ссылка подписки или share-link', flow: DirectFlow.ImportText },
    { index: '02', title: 'Вставить из буфера', detail: 'Ссылка или готовый конфиг', flow: DirectFlow.ImportClipboard },
    { index: '03', title: 'Ручной ввод ссылки', detail: 'vless / vmess / trojan / https', flow: DirectFlow.ImportText },
    { index: '04', title: 'Импорт файла', detail: 'JSON, Clash, WireGuard, ovpn', flow: DirectFlow.ImportFile },
    { index: '05', title: 'Вставить конфиг', detail: 'Текст JSON / YAML / URI-список', flow: DirectFlow.ImportConfigText }
  ];

  private requestConnect(): void {
    if (!this.privacyAccepted) {
      this.showPrivacyDisclosure = true;
      DirectHaptics.navigation();
      return;
    }
    this.onToggle();
  }

  // Only payment keeps the native implementation here. Auth and all advanced
  // settings now pass through DirectFlowHost so their dedicated parity views
  // are actually reachable from the app shell.
  private usesNativePort(flow: DirectFlow): boolean { return flow === DirectFlow.Payment; }

  private headerPageIndex(): number { return this.activeFlow !== DirectFlow.None && !this.isSheetFlow(this.activeFlow) ? 5 : this.selectedTab + 1; }
  private openAddMenu(): void { this.isMenuOpen = true; DirectHaptics.navigation(); }
  private closeAddMenu(): void { this.isMenuOpen = false; DirectHaptics.navigation(); }
  private runAddMenuAction(action: AddMenuAction): void {
    this.isMenuOpen = false;
    DirectHaptics.navigation();
    if (action.index === '01') this.handleQRScan();
    else if (action.flow !== null) { this.selectedTab = DirectTab.Management; this.activeFlow = action.flow; }
  }
  private handleQRScan(): void { AppStorage.setOrCreate('pending_qr_mode', true); this.selectedTab = DirectTab.Management; this.activeFlow = DirectFlow.ImportText; }

  @Builder
  SheetContent() {
    if (this.activeFlow !== DirectFlow.None && this.isSheetFlow(this.activeFlow)) {
      DirectFlowHost({
        flow: this.activeFlow,
        onClose: () => this.closeSheet(),
        onFlow: (f: DirectFlow) => {
          if (this.isSheetFlow(f)) this.activeFlow = f;
          else { this.activeFlow = f; this.sheetOpen = false; }
        }
      });
    } else Blank().backgroundColor(DirectTheme.paper).width('100%').height('100%');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Blank().height(DirectTheme.appBarHeight).width('100%');
        if (this.selectedTab === DirectTab.Home) {
          HomePage({
            status: this.status,
            serverName: this.serverName,
            onToggle: () => this.requestConnect(),
            onServerTap: () => this.openSheet(DirectFlow.ServerPicker),
            onReport: () => this.openSheet(DirectFlow.ConnectionReport),
            onProfiles: () => this.openSheet(DirectFlow.Profiles)
          }).layoutWeight(1);
        } else if (this.selectedTab === DirectTab.Locations) {
          LocationsPage({ onFlow: (flow: DirectFlow) => { if (this.isSheetFlow(flow)) this.openSheet(flow); else this.activeFlow = flow; } }).layoutWeight(1);
        } else if (this.selectedTab === DirectTab.Management) {
          ManagementPage({
            onFlow: (flow: DirectFlow) => { if (this.isSheetFlow(flow)) this.openSheet(flow); else this.activeFlow = flow; },
            onAddSubscription: () => this.openAddMenu()
          }).layoutWeight(1);
        } else {
          ProfilePage({ onFlow: (flow: DirectFlow) => { if (this.isSheetFlow(flow)) this.openSheet(flow); else this.activeFlow = flow; } }).layoutWeight(1);
        }

        Row() {
          this.tab('Главная', DirectTab.Home, 1);
          this.tab('Локации', DirectTab.Locations, 2);
          this.tab('Управление', DirectTab.Management, 3);
          this.tab('Профиль', DirectTab.Profile, 4);
        }.width('100%').height(DirectTheme.tabBarHeight).backgroundColor(DirectTheme.paper).border({ width: { top: 1 }, color: DirectTheme.line });
      }.width('100%').height('100%').backgroundColor(DirectTheme.paper);

      if (this.isMenuOpen) {
        Column() {
          Blank().height(DirectTheme.appBarHeight);
          Column().width('100%').layoutWeight(1).backgroundColor('#1F000000').onClick(() => this.closeAddMenu());
        }.width('100%').height('100%').zIndex(30);
        Column() {
          Blank().height(DirectTheme.appBarHeight + 4);
          this.addSubscriptionMenu();
        }.width('100%').height('100%').alignItems(HorizontalAlign.End).padding({ right: 16 }).zIndex(40);
      }

      Column() { this.appHeader(); }.width('100%').height(DirectTheme.appBarHeight).zIndex(150);

      if (this.activeFlow !== DirectFlow.None && !this.isSheetFlow(this.activeFlow)) {
        Column() {
          Blank().height(DirectTheme.appBarHeight).width('100%');
          if (this.activeFlow === DirectFlow.Plans || this.activeFlow === DirectFlow.Constructor) {
            DirectPlanParityHost({
              flow: this.activeFlow,
              onClose: () => { this.activeFlow = DirectFlow.None; },
              onFlow: (flow: DirectFlow) => { this.activeFlow = flow; }
            }).layoutWeight(1);
          } else if (this.usesNativePort(this.activeFlow)) {
            DirectNativeFlowHost({
              flow: this.activeFlow,
              onClose: () => { this.activeFlow = DirectFlow.None; },
              onFlow: (flow: DirectFlow) => { this.activeFlow = flow; }
            }).layoutWeight(1);
          } else {
            DirectFlowHost({
              flow: this.activeFlow,
              onClose: () => { this.activeFlow = DirectFlow.None; },
              onFlow: (flow: DirectFlow) => { this.activeFlow = flow; }
            }).layoutWeight(1);
          }
        }.width('100%').height('100%').backgroundColor(DirectTheme.paper).zIndex(100);
      }

      if (this.showPrivacyDisclosure) {
        DirectPrivacyDisclosure({
          onAccept: () => { this.privacyAccepted = true; this.showPrivacyDisclosure = false; this.onToggle(); },
          onDecline: () => { this.showPrivacyDisclosure = false; }
        }).zIndex(200);
      }
    }
    .width('100%').height('100%')
    .bindSheet($$this.sheetOpen, this.SheetContent, {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: false,
      backgroundColor: DirectTheme.paper,
      onDisappear: () => {
        if (this.isSheetFlow(this.activeFlow)) this.activeFlow = DirectFlow.None;
        this.sheetOpen = false;
      }
    });
  }

  @Builder
  appHeader() {
    Stack({ alignContent: Alignment.End }) {
      Row() {
        if (this.activeFlow !== DirectFlow.None && !this.isSheetFlow(this.activeFlow)) {
          Column() {
            DirectIcon({ name: DirectIconName.ArrowLeft, iconSize: 14, color: DirectTheme.muted, weight: 1.6 });
          }.width(36).height(36).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).margin({ right: 8 }).onClick(() => { DirectHaptics.navigation(); this.activeFlow = DirectFlow.None; });
        }
        Column() {
          Text('VPN DIRECT').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
          Text('PRIVATE NETWORK').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 1 });
        }.alignItems(HorizontalAlign.Start);
        Blank();
      }.width('100%').height(DirectTheme.appBarHeight).padding({ left: DirectTheme.pageHorizontal }).backgroundColor(DirectTheme.paper).border({ width: { bottom: 1 }, color: DirectTheme.line });
      Row() {
        Text(`VPN / ${String(this.headerPageIndex()).padStart(2, '0')}`).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ right: 8 });
        Column() { DirectIcon({ name: this.isMenuOpen ? DirectIconName.Xmark : DirectIconName.Menu, iconSize: this.isMenuOpen ? 12 : 14, color: this.isMenuOpen ? DirectTheme.acid : DirectTheme.ink, weight: 1.6 }); }
          .width(36).height(36).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).backgroundColor(this.isMenuOpen ? DirectTheme.ink : Color.Transparent).border({ width: 1, color: DirectTheme.ink }).onClick(() => { this.isMenuOpen = !this.isMenuOpen; DirectHaptics.navigation(); });
      }.padding({ right: 12 });
    }.width('100%').height(DirectTheme.appBarHeight);
  }

  @Builder
  addSubscriptionMenu() {
    Column() {
      Row() {
        Text('ДОБАВИТЬ ПОДПИСКУ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor('#7AFFFFFF').fontFamily('monospace');
        Blank();
        Text('05 ВАРИАНТОВ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor('#7AFFFFFF').fontFamily('monospace');
      }.width('100%').padding(16);
      ForEach(this.addMenuActions, (action: AddMenuAction) => {
        Row() {
          Text(action.index).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor('#59FFFFFF').fontFamily('monospace').margin({ right: 13 });
          Column() {
            Text(action.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(DirectTheme.white);
            Text(action.detail).fontSize(10).fontColor('#75FFFFFF').margin({ top: 4 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          DirectIcon({ name: DirectIconName.ArrowUpRight, iconSize: 12, color: DirectTheme.acid, weight: 1.5 });
        }.width('100%').height(DirectTheme.menuRowHeight).padding({ left: 16, right: 16 }).border({ width: { top: 1 }, color: '#1AFFFFFF' }).onClick(() => this.runAddMenuAction(action));
      });
    }.width(350).backgroundColor(DirectTheme.ink).shadow({ radius: 24, color: '#3D000000', offsetX: 0, offsetY: 12 });
  }

  @Builder
  tab(title: string, tab: DirectTab, index: number) {
    Column() {
      Text(String(index).padStart(2, '0')).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(this.selectedTab === tab ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace');
      Text(title).fontSize(11).fontWeight(this.selectedTab === tab ? FontWeight.Bold : FontWeight.Regular).fontColor(DirectTheme.ink).margin({ top: 3 });
    }.layoutWeight(1).justifyContent(FlexAlign.Center).height('100%').backgroundColor(this.selectedTab === tab ? DirectTheme.acidSelected : Color.Transparent).onClick(() => { if (this.selectedTab !== tab) DirectHaptics.navigation(); this.selectedTab = tab; this.isMenuOpen = false; });
  }
}
