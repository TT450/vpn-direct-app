import { DirectTheme, DirectTypography, DirectSpacing } from '../ui/Theme';

@Component
export struct ManagementPage {
  build() {
    Column() {
      Text('Управление').fontSize(DirectTypography.title).fontWeight(FontWeight.Bold).fontColor(DirectTheme.textPrimary)
        .width('100%').margin({ bottom: DirectSpacing.lg });
      Column() {
        Text('VPN Direct').fontSize(DirectTypography.headline).fontWeight(FontWeight.Bold).fontColor(DirectTheme.textPrimary);
        Text('Сервис не подключён').fontSize(DirectTypography.secondary).fontColor(DirectTheme.textSecondary).margin({ top: 6 });
      }.width('100%').padding(18).backgroundColor(DirectTheme.surface).borderRadius(DirectTheme.radiusMedium);
      Blank();
      Text('Здесь будут активный сервис, срок действия, трафик и управление подключением.')
        .fontSize(DirectTypography.secondary).fontColor(DirectTheme.textSecondary).width('100%');
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: 24, bottom: 24 }).backgroundColor(DirectTheme.background);
  }
}
