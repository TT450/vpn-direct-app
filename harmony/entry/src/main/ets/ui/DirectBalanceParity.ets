import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlows';

interface BalanceTransactionData {
  title: string;
  kind: string;
  amount: string;
  debit: boolean;
  date: string;
}

const SAMPLE_TRANSACTIONS: BalanceTransactionData[] = [];

@Component
export struct DirectBalanceParityHost {
  @Prop flow: DirectFlow = DirectFlow.Balance;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

  build() {
    if (this.flow === DirectFlow.BalanceTopUp) {
      DirectBalanceTopUpParity({ onClose: this.onClose, onFlow: this.onFlow });
    } else {
      DirectBalanceAccountParity({ onClose: this.onClose, onFlow: this.onFlow });
    }
  }
}

@Component
struct DirectBalanceChrome {
  @Prop kicker: string = 'АККАУНТ / БАЛАНС';
  @Prop title: string = 'Баланс';
  @Prop subtitle: string = 'Средства для быстрых покупок VPN Direct';
  @Prop onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent)
          .width(36).height(36).onClick(() => { DirectHaptics.navigation(); this.onClose(); });
        Column() {
          Text(this.kicker).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Text(this.title).fontSize(22).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 6 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      }.width('100%').height(54);
      Text(this.subtitle).fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 18 });
    }.width('100%');
  }
}

@Component
struct DirectBalanceAccountParity {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State balance: string = '—';
  @State pending: boolean = false;
  private readonly transactions: BalanceTransactionData[] = SAMPLE_TRANSACTIONS;

  build() {
    Scroll() {
      Column() {
        DirectBalanceChrome({ onClose: this.onClose });
        this.hero();
        Row() {
          Text('Пополнить баланс').fontSize(12).fontWeight(FontWeight.Semibold).fontColor(DirectTheme.acid);
          Blank(); Text('+').fontSize(16).fontColor(DirectTheme.acid);
        }.width('100%').height(50).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).margin({ top: 12 })
          .onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.BalanceTopUp); });

        if (this.pending) {
          Text('Покупка ожидает синхронизации средств.').fontSize(10).fontColor(DirectTheme.ink).lineSpacing(3).margin({ top: 10 });
          Row() { Text('СИНХРОНИЗИРОВАТЬ СРЕДСТВА').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('↻').fontSize(13).fontColor(DirectTheme.acid); }
            .width('100%').height(44).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 8 })
            .onClick(() => DirectHaptics.selection());
        }

        Row() { Text('ИСТОРИЯ БАЛАНСА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text(String(this.transactions.length).padStart(2, '0')).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }
          .width('100%').height(38).border({ width: { top: 1 }, color: DirectTheme.ink }).margin({ top: 23 });
        if (this.transactions.length === 0) {
          Text('Операций пока нет. Пополнение и покупки через баланс появятся здесь.').fontSize(10).fontColor(DirectTheme.muted).lineSpacing(3).padding({ top: 18, bottom: 18 });
        } else {
          ForEach(this.transactions, (item: BalanceTransactionData) => this.transactionRow(item));
        }
        Blank().height(24);
      }.padding({ left: 20, right: 20, top: 24 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private hero() {
    Column() {
      Text('ДОСТУПНО').fontSize(9).fontWeight(FontWeight.Bold).fontColor(Color.White).opacity(0.42).fontFamily('monospace');
      Text(this.balance).fontSize(31).fontWeight(FontWeight.Semibold).fontColor(Color.White).fontFamily('monospace').margin({ top: 10 });
      Text('Можно использовать без повторной оплаты при покупке подписки.').fontSize(10).fontColor(Color.White).opacity(0.48).margin({ top: 10 });
    }.width('100%').padding(17).backgroundColor(DirectTheme.ink).border({ width: 1, color: DirectTheme.acid });
  }

  @Builder
  private transactionRow(item: BalanceTransactionData) {
    Row() {
      Text(item.debit ? '−' : '+').fontSize(18).fontWeight(FontWeight.Bold).fontColor(item.debit ? DirectTheme.danger : DirectTheme.green).fontFamily('monospace').width(40);
      Column() { Text(item.title).fontSize(12).fontWeight(FontWeight.Semibold); Row() { Text(item.kind).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(item.date).fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ left: 6 }); } }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Text(item.amount).fontSize(10).fontWeight(FontWeight.Semibold).fontColor(DirectTheme.ink).fontFamily('monospace');
    }.width('100%').minHeight(62).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }
}

@Component
struct DirectBalanceTopUpParity {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State purchasing: boolean = false;
  @State success: boolean = false;

  build() {
    Stack() {
      Scroll() {
        Column() {
          DirectBalanceChrome({ kicker: 'DIRECT / БАЛАНС', title: 'Пополнить баланс', subtitle: 'Пополнение через Apple — средства сразу на балансе', onClose: this.onClose });
          this.hero();
          Row() { Text('ПОПОЛНЕНИЕ · APPLE').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text('IN-APP').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }
            .width('100%').height(38).border({ width: { top: 1 }, color: DirectTheme.ink }).margin({ top: 23 });
          this.productRow('10 USD', 'Зачислится на баланс · Apple In-App', true);
          this.productRow('25 USD', 'Зачислится на баланс · Apple In-App', false);
          this.productRow('50 USD', 'Зачислится на баланс · Apple In-App', false);
          Text('Покупка проходит через Apple. После подтверждения сумма зачисляется на баланс.').fontSize(10).fontColor(DirectTheme.muted).lineSpacing(3).padding({ top: 16, bottom: 24 });
        }.padding({ left: 20, right: 20 });
      }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
      if (this.purchasing || this.success) {
        Column() {
          Text(this.success ? 'БАЛАНС ПОПОЛНЕН' : 'ПОКУПКА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
          Text(this.success ? 'Средства зачислены' : 'Ожидаем подтверждение Apple').fontSize(24).fontWeight(FontWeight.Semibold).fontColor(DirectTheme.ink).margin({ top: 7 });
          Row() { Text(this.success ? 'Готово' : 'Отмена').fontSize(11).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontSize(13).fontColor(DirectTheme.acid); }.width('100%').height(50).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).margin({ top: 16 })
            .onClick(() => { this.purchasing = false; this.success = false; this.onClose(); });
        }.width('100%').padding(18).backgroundColor(DirectTheme.paper).border({ width: 1, color: DirectTheme.line }).alignRules({ bottom: { anchor: '__container__', align: VerticalAlign.Bottom }, left: { anchor: '__container__', align: HorizontalAlign.Start }, right: { anchor: '__container__', align: HorizontalAlign.End } });
      }
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private hero() {
    Row() { Column() { Text('ТЕКУЩИЙ БАЛАНС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(Color.White).opacity(0.42).fontFamily('monospace'); Text('—').fontSize(26).fontWeight(FontWeight.Semibold).fontColor(Color.White).fontFamily('monospace').margin({ top: 6 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('USD').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(52).height(52).textAlign(TextAlign.Center).border({ width: 1, color: DirectTheme.acid }); }.width('100%').padding(16).backgroundColor(DirectTheme.ink).border({ width: 1, color: DirectTheme.acid });
  }

  @Builder
  private productRow(credit: string, detail: string, recommended: boolean) {
    Row() { Text('+').fontSize(17).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(45).height(45).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink); Column() { Text('Пополнить').fontSize(13).fontWeight(FontWeight.Semibold); Text(credit).fontSize(11).fontWeight(FontWeight.Semibold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 4 }); Text(detail).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 2 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('→').fontSize(11).fontWeight(FontWeight.Bold); }
      .width('100%').minHeight(70).padding(12).backgroundColor(recommended ? DirectTheme.acid : Color.Transparent).opacity(recommended ? 1 : 0.96).border({ width: 1, color: recommended ? DirectTheme.green : DirectTheme.line }).margin({ top: 7 })
      .onClick(() => { DirectHaptics.selection(); this.purchasing = true; });
  }
}
