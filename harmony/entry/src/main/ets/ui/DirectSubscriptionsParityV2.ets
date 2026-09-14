import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { ImportedSubscriptionStore, ImportedSubscription } from '../vpn/ImportedSubscriptionStore';

@Component
export struct DirectSubscriptionsParityV2 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State items: ImportedSubscription[] = [];
  @State activeId: string = '';

  aboutToAppear(): void { this.reload(); }
  private reload(): void { this.items = ImportedSubscriptionStore.list(); this.activeId = ImportedSubscriptionStore.activeId(); }

  private choose(item: ImportedSubscription): void {
    ImportedSubscriptionStore.setActive(item.id);
    this.reload();
    DirectHaptics.selection();
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column() { Text('DIRECT / SUBSCRIPTIONS').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Подписки').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 7 }); Text('VPN Direct — основной доступ; внешние — по желанию').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 5 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Text('×').fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).width(38).height(38).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onClose(); });
        }.width('100%').padding({ top: DirectTheme.pageTop, bottom: 20 });

        if (this.items.length === 0) {
          Column() {
            Text('НЕТ ДОБАВЛЕННЫХ ПОДПИСОК').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
            Text('Добавьте URL, QR, файл или sing-box конфиг.').fontSize(15).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 8 });
          }.width('100%').padding(16).border({ width: 1, color: DirectTheme.line });
        } else {
          Row() { Text('ДОБАВЛЕННЫЕ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text(String(this.items.length).padStart(2, '0')).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(38).margin({ top: 4 }).border({ width: { top: 1 }, color: DirectTheme.ink });
          ForEach(this.items, (item: ImportedSubscription) => this.subscriptionRow(item), (item: ImportedSubscription) => item.id);
        }

        Row() { Text('+ ДОБАВИТЬ ПОДПИСКУ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontSize(13).fontColor(DirectTheme.acid); }.width('100%').height(52).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).margin({ top: 16 }).onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.ImportText); });
        Blank().height(24);
      }.width('100%').padding({ left: 20, right: 20, bottom: 24 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private subscriptionRow(item: ImportedSubscription) {
    const active = this.activeId === item.id;
    Row() {
      Text(active ? '✓' : 'SUB').fontSize(8).fontWeight(FontWeight.Bold).fontColor(active ? DirectTheme.green : DirectTheme.acid).fontFamily('monospace').textAlign(TextAlign.Center).width(40).height(40).backgroundColor(DirectTheme.ink);
      Column() { Text(item.name.length > 0 ? item.name : 'Подписка').fontSize(13).fontWeight(600).fontColor(DirectTheme.ink).maxLines(1); Text(item.url.length > 0 ? item.url : 'sing-box JSON').fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').maxLines(1).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 });
      Text(active ? 'АКТИВНА' : 'ВЫБРАТЬ').fontSize(8).fontWeight(FontWeight.Bold).fontColor(active ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace');
    }.width('100%').constraintSize({ minHeight: 64 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => this.choose(item));
  }
}
