import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';

interface BalanceTransactionData { title: string; kind: string; amount: string; debit: boolean; date: string; }
const SAMPLE_TRANSACTIONS: BalanceTransactionData[] = [];

@Component
export struct DirectBalanceParityHost {
  @Prop flow: DirectFlow = DirectFlow.Balance;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() { if (this.flow === DirectFlow.BalanceTopUp) DirectBalanceTopUpParity({ onClose: this.onClose, onFlow: this.onFlow }); else DirectBalanceAccountParity({ onClose: this.onClose, onFlow: this.onFlow }); }
}

@Component
struct DirectBalanceAccountParity {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State balance: string = '—';
  private readonly transactions: BalanceTransactionData[] = SAMPLE_TRANSACTIONS;
  build() {
    Scroll() { Column() {
      this.chrome('АККАУНТ / БАЛАНС', 'Баланс', 'Средства для быстрых операций', this.onClose);
      Column() { Text('ТЕКУЩИЙ БАЛАНС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(this.balance).fontSize(30).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 6 }); Text('USD').fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 2 }); }
        .width('100%').padding(16).border({ width: 1, color: DirectTheme.line }).margin({ bottom: 12 });
      Row() { Text('ПОПОЛНИТЬ БАЛАНС').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontColor(DirectTheme.acid); }.width('100%').height(52).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.BalanceTopUp); });
      Text('ИСТОРИЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 22, bottom: 8 });
      if (this.transactions.length === 0) { Text('История пока пуста').fontSize(13).fontColor(DirectTheme.ink).width('100%').padding(16).border({ width: 1, color: DirectTheme.line }); Text('Здесь появятся операции после первой транзакции.').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 6 }); }
      else ForEach(this.transactions, (tx: BalanceTransactionData) => { this.transaction(tx); });
    }.padding({ left: 20, right: 20, bottom: 28 }) }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  @Builder private chrome(kicker: string, title: string, subtitle: string, onClose: () => void) { Row() { Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36).onClick(() => { DirectHaptics.navigation(); onClose(); }); Column() { Text(kicker).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(title).fontSize(22).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 6 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); }.width('100%').height(54); Text(subtitle).fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 18 }); }
  @Builder private transaction(tx: BalanceTransactionData) { Row() { Column() { Text(tx.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Text(tx.kind + ' · ' + tx.date).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text((tx.debit ? '−' : '+') + tx.amount).fontSize(11).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').minHeight(54).border({ width: { bottom: 1 }, color: DirectTheme.line }); }
}

@Component
struct DirectBalanceTopUpParity {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State selected: number = 2;
  @State pending: boolean = false;
  private readonly amounts: string[] = ['$5', '$10', '$25', '$50'];
  build() { Column() {
    Row() { Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); Column() { Text('АККАУНТ / БАЛАНС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Пополнение').fontSize(22).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 6 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); }.width('100%').height(54);
    Text('Выберите сумму для баланса').fontSize(13).fontColor(DirectTheme.muted).margin({ bottom: 18 });
    Row() { ForEach(this.amounts, (amount: string, index: number) => { Text(amount).fontSize(11).fontWeight(FontWeight.Bold).fontFamily('monospace').fontColor(this.selected === index ? DirectTheme.acid : DirectTheme.ink).layoutWeight(1).height(48).textAlign(TextAlign.Center).backgroundColor(this.selected === index ? DirectTheme.ink : Color.Transparent).border({ width: 1, color: DirectTheme.line }).onClick(() => { this.selected = index; DirectHaptics.selection(); }); }); }.width('100%');
    Column() { Text('APPLE IN-APP').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Платёжный адаптер Harmony').fontSize(14).fontColor(DirectTheme.ink).margin({ top: 7 }); Text(this.pending ? 'Ожидание результата транзакции…' : 'UI готов; реальная транзакция не имитируется до подключения Store/payment adapter.').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 5 }); }.width('100%').padding(16).border({ width: 1, color: DirectTheme.line }).margin({ top: 18 });
    Row() { Text(this.pending ? 'ОЖИДАНИЕ' : 'ПРОДОЛЖИТЬ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontColor(DirectTheme.acid); }.width('100%').height(56).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).margin({ top: 12 }).onClick(() => { this.pending = true; DirectHaptics.selection(); });
    Blank().layoutWeight(1);
  }.padding({ left: 20, right: 20, top: 18, bottom: 24 }).width('100%').height('100%').backgroundColor(DirectTheme.paper); }
}