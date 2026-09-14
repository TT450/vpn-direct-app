import { DirectTheme, DirectTypography, DirectSpacing } from '../ui/Theme';

@Component
export struct ProfilePage {
  build() {
    Column() {
      Text('Профиль').fontSize(DirectTypography.title).fontWeight(FontWeight.Bold).fontColor(DirectTheme.textPrimary)
        .width('100%').margin({ bottom: DirectSpacing.lg });
      Row() {
        Column() {
          Text('VPN Direct').fontSize(DirectTypography.headline).fontWeight(FontWeight.Bold).fontColor(DirectTheme.textPrimary);
          Text('Аккаунт не выполнен').fontSize(DirectTypography.secondary).fontColor(DirectTheme.textSecondary).margin({ top: 4 });
        }.alignItems(HorizontalAlign.Start);
        Blank();
        Text('›').fontSize(22).fontColor(DirectTheme.textSecondary);
      }.width('100%').padding(18).backgroundColor(DirectTheme.surface).borderRadius(DirectTheme.radiusMedium);
      Column() {
        Text('Настройки').fontSize(DirectTypography.headline).fontWeight(FontWeight.Bold).fontColor(DirectTheme.textPrimary);
        Text('Юридическая информация').fontSize(DirectTypography.body).fontColor(DirectTheme.textPrimary).margin({ top: 18 });
        Text('Конфиденциальность').fontSize(DirectTypography.body).fontColor(DirectTheme.textPrimary).margin({ top: 18 });
        Text('О приложении').fontSize(DirectTypography.body).fontColor(DirectTheme.textPrimary).margin({ top: 18 });
      }.width('100%').padding(18).backgroundColor(DirectTheme.surface).borderRadius(DirectTheme.radiusMedium).margin({ top: DirectSpacing.lg }).alignItems(HorizontalAlign.Start);
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: 24, bottom: 24 }).backgroundColor(DirectTheme.background);
  }
}
