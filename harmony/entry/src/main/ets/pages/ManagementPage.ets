import { DirectTheme, DirectTypography } from '../ui/Theme';

@Component
export struct ManagementPage {
  build() {
    Column() {
      Text('DIRECT / MANAGEMENT').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
      Text('Управление').fontSize(DirectTypography.pageTitle).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%').margin({ top: 7 });
      Text('Сервис, подписка и состояние доступа').fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ top: 4, bottom: 16 });

      Row() {
        Rectangle().width(4).height(42).fill(DirectTheme.danger);
        Column() {
          Text('VPN DIRECT').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
          Text('Сервис не подключён').fontSize(11).fontColor(DirectTheme.muted).margin({ top: 4 });
        }.alignItems(HorizontalAlign.Start).margin({ left: 11 });
        Blank();
        Text('ОЖИДАНИЕ').fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
      }.width('100%').height(66).padding({ left: 13, right: 13 }).border({ width: 1, color: DirectTheme.line });

      Row() {
        Column() { Text('—').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('СРОК').fontSize(7).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 3 }); }.layoutWeight(1);
        Rectangle().width(1).height(28).fill(DirectTheme.line);
        Column() { Text('—').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('ТРАФИК').fontSize(7).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 3 }); }.layoutWeight(1);
        Rectangle().width(1).height(28).fill(DirectTheme.line);
        Column() { Text('—').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('УСТРОЙСТВА').fontSize(7).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 3 }); }.layoutWeight(1);
      }.width('100%').height(66).border({ width: { bottom: 1 }, color: DirectTheme.line });

      Blank();
      Text('АКТИВНЫЙ СЕРВИС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
      Text('Подключите сервис или выберите тариф, чтобы управлять сроком действия, трафиком и подключением.')
        .fontSize(13).fontColor(DirectTheme.ink).width('100%').margin({ top: 8 });
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 24 }).backgroundColor(DirectTheme.paper);
  }
}
