import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectFlow } from '../ui/DirectFlows';

@Component
export struct ProfilePage {
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

  build() {
    Column() {
      Text('DIRECT / PROFILE').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
      Text('Профиль').fontSize(DirectTypography.pageTitle).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%').margin({ top: 7 });
      Text('Аккаунт и настройки VPN Direct').fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ top: 4, bottom: 16 });
      Row() { Rectangle().width(4).height(42).fill(DirectTheme.acid); Column() { Text('VPN DIRECT').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('Вы не вошли в аккаунт').fontSize(11).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).margin({ left: 11 }); Blank(); Text('→').fontSize(16).fontColor(DirectTheme.muted); }.width('100%').height(66).padding({ left: 13, right: 13 }).border({ width: 1, color: DirectTheme.line }).onClick(() => this.onFlow(DirectFlow.AuthLogin));
      Text('АККАУНТ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%').margin({ top: 20, bottom: 8 });
      this.row('01', 'Войти', 'Email, телефон или код бота', DirectFlow.AuthLogin);
      this.row('02', 'Аккаунт', 'Профиль и устройства', DirectFlow.Account);
      this.row('03', 'Баланс', 'Счёт и история платежей', DirectFlow.Balance);
      Text('ПРИЛОЖЕНИЕ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%').margin({ top: 20, bottom: 8 });
      this.row('04', 'Безопасность', 'Защита и системные разрешения', DirectFlow.Security);
      this.row('05', 'Настройки', 'Поведение приложения и туннеля', DirectFlow.ApplicationSettings);
      this.row('06', 'Правовая информация', 'Условия использования', DirectFlow.Legal);
      this.row('07', 'Конфиденциальность', 'Обработка данных', DirectFlow.Privacy);
      this.row('08', 'О приложении', 'VPN Direct / HarmonyOS', DirectFlow.About);
      Blank();
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 24 }).backgroundColor(DirectTheme.paper);
  }

  @Builder
  row(index: string, title: string, subtitle: string, flow: DirectFlow) {
    Row() { Text(index).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width(30); Column() { Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('→').fontSize(15).fontColor(DirectTheme.muted); }.width('100%').height(55).padding({ left: 12, right: 12 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => this.onFlow(flow));
  }
}
