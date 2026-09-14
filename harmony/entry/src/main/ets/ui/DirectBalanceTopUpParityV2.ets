import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';

@Component
export struct DirectBalanceTopUpParityV2 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State selected: number = 1;
  @State message: string = '';
  private readonly amounts: string[] = ['$5', '$10', '$25', '$50'];

  build() {
    Column() {
      Row() { Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); Column() { Text('АККАУНТ / БАЛАНС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Пополнение').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 6 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); }.width('100%').height(54);
      Text('Выберите сумму для баланса').fontSize(13).fontColor(DirectTheme.muted).margin({ bottom: 18 });
      Row() { ForEach(this.amounts, (amount: string, index: number) => Text(amount).fontSize(11).fontWeight(FontWeight.Bold).fontFamily('monospace').fontColor(this.selected === index ? DirectTheme.acid : DirectTheme.ink).layoutWeight(1).height(48).textAlign(TextAlign.Center).backgroundColor(this.selected === index ? DirectTheme.ink : Color.Transparent).border({ width: 1, color: DirectTheme.line }).onClick(() => { this.selected = index; this.message = ''; DirectHaptics.selection(); })); }.width('100%');
      Column() { Text('ПЛАТЁЖНЫЙ АДАПТЕР').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Ожидает подключения backend / Store').fontSize(14).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 7 }); Text('Сумма и выбор готовы, но приложение не создаёт фиктивную транзакцию. После подключения платёжного адаптера эта кнопка будет запускать реальный checkout.').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 6 }); }.width('100%').padding(16).border({ width: 1, color: DirectTheme.line }).margin({ top: 18 });
      if (this.message.length > 0) Text(this.message).fontSize(11).fontColor(DirectTheme.muted).width('100%').padding(12).border({ width: 1, color: DirectTheme.line }).margin({ top: 12 });
      Row() { Text('ПРОДОЛЖИТЬ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontColor(DirectTheme.acid); }.width('100%').height(DirectTheme.balanceTopUpHeight).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).margin({ top: 12 }).onClick(() => { this.message = 'Платёжный адаптер не подключён. Транзакция не создана.'; DirectHaptics.error(); });
      Blank().layoutWeight(1);
    }.padding({ left: 20, right: 20, top: DirectTheme.pageTop, bottom: 24 }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}
