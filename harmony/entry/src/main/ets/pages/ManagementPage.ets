import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics } from '../ui/Haptics';
import { DirectFlow } from '../ui/DirectFlows';

@Component
export struct ManagementPage {
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

  build() {
    Scroll() {
      Column() {
        Text('DIRECT / MANAGEMENT').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
        Text('Управление').fontSize(DirectTypography.pageTitle).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 7 });
        Text('Подписка, лимиты и настройки VPN Direct').fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ top: 4, bottom: 16 });

        Column() {
          Row() {
            Column() {
              Text('01 / ПОДПИСКА').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#B8F069').fontFamily('monospace');
              Text('БЕЗ ТАРИФА').fontSize(24).fontWeight(FontWeight.Medium).fontColor(DirectTheme.white).fontFamily('monospace').margin({ top: 4 });
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Text('○ НЕТ ТАРИФА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          }.width('100%');
          Text('— · 1 устройство').fontSize(9).fontColor('#94FFFFFF').fontFamily('monospace').margin({ top: 8 });
          Rectangle().height(1).width('100%').fill('#29FFFFFF').margin({ top: 14, bottom: 14 });
          Row() {
            Column() { Text('ДО ОКОНЧАНИЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#8CFFFFFF').fontFamily('monospace'); Text('—').fontSize(20).fontWeight(FontWeight.Medium).fontColor(DirectTheme.white).fontFamily('monospace').margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Column() { Text('ОКОНЧАНИЕ').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#8CFFFFFF').fontFamily('monospace'); Text('—').fontSize(11).fontWeight(FontWeight.Bold).fontColor(DirectTheme.white).fontFamily('monospace').margin({ top: 4 }); }.alignItems(HorizontalAlign.End);
          }.width('100%');
        }.width('100%').padding(15).backgroundColor(DirectTheme.ink).border({ width: 1.5, color: DirectTheme.ink });

        Row() {
          Text('VPN DIRECT').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#B8F069').fontFamily('monospace');
          Blank();
          Text('Выбрать тариф').fontSize(16).fontWeight(FontWeight.Medium).fontColor(DirectTheme.acid);
          Text('→').fontSize(13).fontColor(DirectTheme.acid).margin({ left: 10 });
        }.width('100%').height(62).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).margin({ top: 12 }).onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.Plans); });

        this.section('02 / ИСПОЛЬЗОВАНИЕ');
        Row() { Text('VPN TRAFFIC').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text('—').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').height(34);
        Rectangle().width('100%').height(5).fill(DirectTheme.line);

        this.section('03 / НАСТРОЙКА');
        this.row('Изменить тариф', 'ГОТОВЫЕ ПЛАНЫ', DirectFlow.Plans);
        this.row('Изменить устройства', 'КОНСТРУКТОР', DirectFlow.Constructor);
        this.row('Изменить трафик', 'КОНСТРУКТОР', DirectFlow.Constructor);

        this.section('04 / ДРУГИЕ ПОДПИСКИ');
        Text('Нет добавленных подписок').fontSize(12).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%').margin({ top: 10 });
        Text('Добавьте стороннюю подписку, если хотите использовать её вместе с VPN Direct.').fontSize(9).fontColor(DirectTheme.muted).width('100%').margin({ top: 5, bottom: 13 });
        Row() { Text('+').fontSize(14).fontColor(DirectTheme.acid); Text('ДОБАВИТЬ ПОДПИСКУ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').margin({ left: 8 }); Blank(); Text('→').fontColor(DirectTheme.acid); }.width('100%').height(48).padding({ left: 13, right: 13 }).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.ImportText); });
        Blank().height(28);
      }.padding({ left: 20, right: 20, top: 24, bottom: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private section(title: string) { Text(title).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').height(36).padding({ top: 18 }).border({ width: { top: 1 }, color: DirectTheme.ink }).margin({ top: 18 }); }

  @Builder
  private row(title: string, detail: string, flow: DirectFlow) {
    Row() { Column() { Text(title).fontSize(12).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Text(detail).fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('↗').fontSize(10).fontColor(DirectTheme.ink); }.width('100%').height(52).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); this.onFlow(flow); });
  }
}
