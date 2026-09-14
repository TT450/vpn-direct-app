import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectFlow } from '../ui/DirectFlows';

@Component
export struct ManagementPage {
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

  build() {
    Column() {
      Text('DIRECT / MANAGEMENT').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
      Text('Управление').fontSize(DirectTypography.pageTitle).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%').margin({ top: 7 });
      Text('Сервис, подписка и состояние доступа').fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ top: 4, bottom: 16 });
      Row() { Rectangle().width(4).height(42).fill(DirectTheme.danger); Column() { Text('VPN DIRECT').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('Сервис не подключён').fontSize(11).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).margin({ left: 11 }); Blank(); Text('ОЖИДАНИЕ').fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); }.width('100%').height(66).padding({ left: 13, right: 13 }).border({ width: 1, color: DirectTheme.line });
      Row() { this.metric('—', 'СРОК'); Rectangle().width(1).height(28).fill(DirectTheme.line); this.metric('—', 'ТРАФИК'); Rectangle().width(1).height(28).fill(DirectTheme.line); this.metric('—', 'УСТРОЙСТВА'); }.width('100%').height(66).border({ width: { bottom: 1 }, color: DirectTheme.line });
      Text('СЕРВИС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%').margin({ top: 20, bottom: 8 });
      this.row('01', 'Активная подписка', 'Срок, трафик и устройства', DirectFlow.Subscription);
      this.row('02', 'Профили', 'Конфигурации и импорт', DirectFlow.Profiles);
      this.row('03', 'Тарифы / конструктор', 'Продление и настройка', DirectFlow.Plans);
      this.row('04', 'Баланс', 'Счёт и пополнение', DirectFlow.Balance);
      this.row('05', 'Доступ', 'Аккаунт или импорт', DirectFlow.Access);
      this.row('06', 'Диагностика', 'Состояние Core и туннеля', DirectFlow.Diagnostics);
      Blank();
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 24 }).backgroundColor(DirectTheme.paper);
  }

  @Builder metric(value: string, label: string) { Column() { Text(value).fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text(label).fontSize(7).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 3 }); }.layoutWeight(1); }

  @Builder row(index: string, title: string, subtitle: string, flow: DirectFlow) {
    Row() { Text(index).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width(30); Column() { Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('→').fontSize(15).fontColor(DirectTheme.muted); }.width('100%').height(55).padding({ left: 12, right: 12 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => this.onFlow(flow));
  }
}
