import { DirectTheme, DirectTypography } from '../ui/Theme';
import { HomePage } from '../pages/HomePage';
import { LocationsPage } from '../pages/LocationsPage';
import { ManagementPage } from '../pages/ManagementPage';
import { ProfilePage } from '../pages/ProfilePage';

/** Mirrors iOS AppTab exactly: plans are a detail flow, not a bottom tab. */
export enum DirectTab {
  Home = 0,
  Locations = 1,
  Management = 2,
  Profile = 3
}

@Component
export struct AppShell {
  @State private selectedTab: DirectTab = DirectTab.Home;
  @Prop status: string = 'Disconnected';
  @Prop serverName: string = 'Авто';
  @Prop onToggle: () => void = () => {};
  @Prop onServerTap: () => void = () => {};

  build() {
    Column() {
      Stack() {
        if (this.selectedTab === DirectTab.Home) {
          HomePage({ status: this.status, serverName: this.serverName, onToggle: this.onToggle, onServerTap: this.onServerTap });
        } else if (this.selectedTab === DirectTab.Locations) {
          LocationsPage();
        } else if (this.selectedTab === DirectTab.Management) {
          ManagementPage();
        } else {
          ProfilePage();
        }
      }.layoutWeight(1).width('100%');

      Row() {
        this.tab('Главная', DirectTab.Home, 1);
        this.tab('Локации', DirectTab.Locations, 2);
        this.tab('Управление', DirectTab.Management, 3);
        this.tab('Профиль', DirectTab.Profile, 4);
      }.width('100%').height(DirectTheme.tabBarHeight)
        .backgroundColor(DirectTheme.paper)
        .border({ width: { top: 1 }, color: DirectTheme.line });
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  tab(title: string, tab: DirectTab, index: number) {
    Column() {
      Text(String(index).padStart(2, '0'))
        .fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(this.selectedTab === tab ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace');
      Text(title)
        .fontSize(11).fontWeight(this.selectedTab === tab ? FontWeight.Medium : FontWeight.Regular).fontColor(DirectTheme.ink)
        .margin({ top: 3 });
    }.layoutWeight(1).justifyContent(FlexAlign.Center).height('100%')
      .backgroundColor(this.selectedTab === tab ? '#24A8F069' : DirectTheme.paper)
      .onClick(() => this.selectedTab = tab);
  }
}
