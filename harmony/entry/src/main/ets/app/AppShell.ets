import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics } from '../ui/Haptics';
import { HomePage } from '../pages/HomePage';
import { LocationsPage } from '../pages/LocationsPage';
import { ManagementPage } from '../pages/ManagementPage';
import { ProfilePage } from '../pages/ProfilePage';
import { DirectFlow, DirectFlowHost } from '../ui/DirectFlows';
import { DirectNativeFlowHost } from '../ui/DirectNativeFlows';

export enum DirectTab {
  Home = 0,
  Locations = 1,
  Management = 2,
  Profile = 3
}

@Component
export struct AppShell {
  @State private selectedTab: DirectTab = DirectTab.Home;
  @State private activeFlow: DirectFlow = DirectFlow.None;
  @Prop status: string = 'Disconnected';
  @Prop serverName: string = 'Авто';
  @Prop onToggle: () => void = () => {};

  private usesNativePort(flow: DirectFlow): boolean {
    return flow === DirectFlow.Plans || flow === DirectFlow.Constructor || flow === DirectFlow.Payment ||
      flow === DirectFlow.AuthLogin || flow === DirectFlow.AuthEmail || flow === DirectFlow.AuthCode ||
      flow === DirectFlow.AuthRegister || flow === DirectFlow.AuthRecovery || flow === DirectFlow.AuthBot ||
      flow === DirectFlow.AuthPhone || flow === DirectFlow.AuthPhoneCode || flow === DirectFlow.AuthSuccess ||
      flow === DirectFlow.Security || flow === DirectFlow.Connection || flow === DirectFlow.Diagnostics ||
      flow === DirectFlow.Activity || flow === DirectFlow.SystemSettings || flow === DirectFlow.ApplicationSettings ||
      flow === DirectFlow.CoreSettings || flow === DirectFlow.TunnelSettings || flow === DirectFlow.OnDemandSettings;
  }

  build() {
    Stack() {
      Column() {
        if (this.selectedTab === DirectTab.Home) {
          HomePage({
            status: this.status,
            serverName: this.serverName,
            onToggle: this.onToggle,
            onServerTap: () => { this.activeFlow = DirectFlow.ServerPicker; },
            onReport: () => { this.activeFlow = DirectFlow.ConnectionReport; },
            onProfiles: () => { this.activeFlow = DirectFlow.Profiles; }
          });
        } else if (this.selectedTab === DirectTab.Locations) {
          LocationsPage();
        } else if (this.selectedTab === DirectTab.Management) {
          ManagementPage({ onFlow: (flow: DirectFlow) => this.activeFlow = flow });
        } else {
          ProfilePage({ onFlow: (flow: DirectFlow) => this.activeFlow = flow });
        }

        Row() {
          this.tab('Главная', DirectTab.Home, 1);
          this.tab('Локации', DirectTab.Locations, 2);
          this.tab('Управление', DirectTab.Management, 3);
          this.tab('Профиль', DirectTab.Profile, 4);
        }.width('100%').height(DirectTheme.tabBarHeight).backgroundColor(DirectTheme.paper)
          .border({ width: { top: 1 }, color: DirectTheme.line });
      }.width('100%').height('100%').backgroundColor(DirectTheme.paper);

      if (this.activeFlow !== DirectFlow.None) {
        Column() {
          if (this.usesNativePort(this.activeFlow)) {
            DirectNativeFlowHost({
              flow: this.activeFlow,
              onClose: () => this.activeFlow = DirectFlow.None,
              onFlow: (flow: DirectFlow) => this.activeFlow = flow
            });
          } else {
            DirectFlowHost({
              flow: this.activeFlow,
              onClose: () => this.activeFlow = DirectFlow.None,
              onFlow: (flow: DirectFlow) => this.activeFlow = flow
            });
          }
        }.width('100%').height('100%').backgroundColor(DirectTheme.paper).zIndex(100);
      }
    }.width('100%').height('100%');
  }

  @Builder
  tab(title: string, tab: DirectTab, index: number) {
    Column() {
      Text(String(index).padStart(2, '0')).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
        .fontColor(this.selectedTab === tab ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace');
      Text(title).fontSize(11).fontWeight(this.selectedTab === tab ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(DirectTheme.ink).margin({ top: 3 });
    }.layoutWeight(1).justifyContent(FlexAlign.Center).height('100%')
      .backgroundColor(this.selectedTab === tab ? DirectTheme.acid : DirectTheme.paper)
      .onClick(() => { if (this.selectedTab !== tab) DirectHaptics.navigation(); this.selectedTab = tab; });
  }
}
