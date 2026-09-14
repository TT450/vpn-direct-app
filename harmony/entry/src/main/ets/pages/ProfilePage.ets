import { DirectTheme, DirectTypography } from '../ui/Theme';

@Component
export struct ProfilePage {
  build() {
    Column() {
      Text('DIRECT / PROFILE').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
      Text('Профиль').fontSize(DirectTypography.pageTitle).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%').margin({ top: 7 });
      Text('Аккаунт и настройки VPN Direct').fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ top: 4, bottom: 16 });

      Row() {
        Rectangle().width(4).height(42).fill(DirectTheme.acid);
        Column() {
          Text('VPN DIRECT').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
          Text('Вы не вошли в аккаунт').fontSize(11).fontColor(DirectTheme.muted).margin({ top: 4 });
        }.alignItems(HorizontalAlign.Start).margin({ left: 11 });
        Blank();
        Text('›').fontSize(16).fontColor(DirectTheme.muted);
      }.width('100%').height(66).padding({ left: 13, right: 13 }).border({ width: 1, color: DirectTheme.line });

      Text('НАСТРОЙКИ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%').margin({ top: 24, bottom: 8 });
      Column() {
        this.row('Юридическая информация');
        this.row('Конфиденциальность');
        this.row('О приложении');
      }.width('100%').border({ width: 1, color: DirectTheme.line });
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 24 }).backgroundColor(DirectTheme.paper);
  }

  @Builder
  row(title: string) {
    Row() {
      Text(title).fontSize(12).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink);
      Blank();
      Text('›').fontSize(14).fontColor(DirectTheme.muted);
    }.width('100%').height(50).padding({ left: 12, right: 12 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }
}
