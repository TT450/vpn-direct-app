import { DirectTheme, DirectTypography } from '../ui/Theme';

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

  build() {
    Column() {
      Stack() {
        Column() {
          if (this.selectedTab === DirectTab.Home) {
            Text('Home').fontSize(DirectTypography.title).fontColor(DirectTheme.textPrimary);
          } else if (this.selectedTab === DirectTab.Locations) {
            Text('Locations').fontSize(DirectTypography.title).fontColor(DirectTheme.textPrimary);
          } else if (this.selectedTab === DirectTab.Plans) {
            Text('Plans').fontSize(DirectTypography.title).fontColor(DirectTheme.textPrimary);
          } else if (this.selectedTab === DirectTab.Management) {
            Text('Management').fontSize(DirectTypography.title).fontColor(DirectTheme.textPrimary);
          } else {
            Text('Profile').fontSize(DirectTypography.title).fontColor(DirectTheme.textPrimary);
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: 24, bottom: 88 });
      }
      .layoutWeight(1)
      .width('100%');

      Row() {
        this.tab('Home', DirectTab.Home);
        this.tab('Locations', DirectTab.Locations);
        this.tab('Plans', DirectTab.Plans);
        this.tab('Manage', DirectTab.Management);
        this.tab('Profile', DirectTab.Profile);
      }
      .width('100%')
      .height(72)
      .padding({ left: 8, right: 8, top: 8, bottom: 8 })
      .backgroundColor(DirectTheme.surface);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DirectTheme.background);
  }

  @Builder
  tab(title: string, tab: DirectTab) {
    Column() {
      Text(title)
        .fontSize(DirectTypography.caption)
        .fontColor(this.selectedTab === tab ? DirectTheme.textPrimary : DirectTheme.textTertiary);
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .onClick(() => {
      this.selectedTab = tab;
    });
  }
}
