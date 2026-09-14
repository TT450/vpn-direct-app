import { DirectTheme, DirectTypography } from '../ui/Theme';
import { HomePage } from '../pages/HomePage';
import { LocationsPage } from '../pages/LocationsPage';
import { ManagementPage } from '../pages/ManagementPage';
import { ProfilePage } from '../pages/ProfilePage';
import { DirectFlow, DirectFlowHost } from '../ui/DirectFlows';

/** Mirrors iOS AppTab exactly: four bottom tabs; all other SwiftUI destinations are detail flows. */
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
  @Prop onServerTap: () => void = () => {};

  build() {
    Stack() {
      Column() {
        if (this.selectedTab === DirectTab.Home) {
          HomePage({ status: this.status, serverName: this.serverName, onToggle: this.onToggle, onServerTap: () => { this.activeFlow = DirectFlow.ServerPicker; } });
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
        }.width('100%').height(DirectTheme.tabBarHeight).backgroundColor(DirectTheme.paper).border({ width: { top: 1 }, color: DirectTheme.line });
      }.width('100%').height('100%').backgroundColor(DirectTheme.paper);

      if (this.activeFlow !== DirectFlow.None) {
        Column() {
          DirectFlowHost({
            flow: this.activeFlow,
            onClose: () => this.activeFlow = DirectFlow.None,
            onFlow: (flow: DirectFlow) => this.activeFlow = flow
          });
        }.width('100%').height('100%').backgroundColor(DirectTheme.paper).zIndex(100);
      }
    }.width('100%').height('100%');
  }

  @Builder
  tab(title: string, tab: DirectTab, index: number) {
    Column() {
      Text(String(index).padStart(2, '0')).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(this.selectedTab === tab ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace');
      Text(title).fontSize(11).fontWeight(this.selectedTab === tab ? FontWeight.Medium : FontWeight.Regular).fontColor(DirectTheme.ink).margin({ top: 3 });
    }.layoutWeight(1).justifyContent(FlexAlign.Center).height('100%').backgroundColor(this.selectedTab === tab ? '#A8F069' : DirectTheme.paper).onClick(() => this.selectedTab = tab);
  }
}
