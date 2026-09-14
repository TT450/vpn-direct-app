import { DirectTheme, DirectTypography } from '../ui/Theme';
import { HomePage } from '../pages/HomePage';
import { LocationsPage } from '../pages/LocationsPage';
import { PlansPage } from '../pages/PlansPage';
import { ManagementPage } from '../pages/ManagementPage';
import { ProfilePage } from '../pages/ProfilePage';

export enum DirectTab {
  Home = 0,
  Locations = 1,
  Plans = 2,
  Management = 3,
  Profile = 4
}

@Component
export struct AppShell {
  @State private selectedTab: DirectTab = DirectTab.Home;
  @Prop status: string = 'Disconnected';
  @Prop serverName: string = 'Авто';
  private onToggle: () => void = () => {};
  private onServerTap: () => void = () => {};

  build() {
    Column() {
      Stack() {
        if (this.selectedTab === DirectTab.Home) {
          HomePage({ status: this.status, serverName: this.serverName, onToggle: this.onToggle, onServerTap: this.onServerTap });
        } else if (this.selectedTab === DirectTab.Locations) {
          LocationsPage();
        } else if (this.selectedTab === DirectTab.Plans) {
          PlansPage();
        } else if (this.selectedTab === DirectTab.Management) {
          ManagementPage();
        } else {
          ProfilePage();
        }
      }.layoutWeight(1).width('100%');

      Row() {
        this.tab('Главная', DirectTab.Home);
        this.tab('Локации', DirectTab.Locations);
        this.tab('Тарифы', DirectTab.Plans);
        this.tab('Управление', DirectTab.Management);
        this.tab('Профиль', DirectTab.Profile);
      }.width('100%').height(72).padding({ left: 8, right: 8, top: 8, bottom: 8 }).backgroundColor(DirectTheme.surface);
    }.width('100%').height('100%').backgroundColor(DirectTheme.background);
  }

  @Builder
  tab(title: string, tab: DirectTab) {
    Column() {
      Text(title).fontSize(DirectTypography.caption)
        .fontColor(this.selectedTab === tab ? DirectTheme.textPrimary : DirectTheme.textTertiary);
    }.layoutWeight(1).justifyContent(FlexAlign.Center).height('100%').onClick(() => this.selectedTab = tab);
  }
}
