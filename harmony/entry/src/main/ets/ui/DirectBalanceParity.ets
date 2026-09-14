import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectBackendRuntime, DirectBalanceTransaction } from '../backend/DirectBackendRuntime';

interface BalanceTransactionData {
  title: string;
  kind: string;
  amount: string;
  debit: boolean;
  date: string;
}

@Component
export struct DirectBalanceParityHost {
  @Prop flow: DirectFlow = DirectFlow.Balance;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    if (this.flow === DirectFlow.BalanceTopUp) {
      DirectBalanceTopUpParity({ onClose: this.onClose, onFlow: this.onFlow });
    } else {
      DirectBalanceAccountParity({ onClose: this.onClose, onFlow: this.onFlow });
    }
  }
}

@Component
struct DirectBalanceAccountParity {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State balance: string = '—';
  @State transactions: BalanceTransactionData[] = [];
  @State errorText: string = '';
  @State loading: boolean = false;

  aboutToAppear(): void {
    void this.reload();
  }

  private formatUsd(cents: number): string {
    const value = Math.max(0, cents) / 100;
    return `$${value.toFixed(2)}`;
  }

  private mapTx(tx: DirectBalanceTransaction): BalanceTransactionData {
    const absCents = Math.abs(tx.amountUsdCents);
    return {
      title: tx.title,
      kind: tx.kind,
      amount: this.formatUsd(absCents),
      debit: tx.debit || tx.amountUsdCents < 0,
      date: tx.createdAt.length > 10 ? tx.createdAt.substring(0, 10) : tx.createdAt
    };
  }

  private kindLabel(kind: string): string {
    if (kind === 'top_up' || kind === 'topUp') return 'ПОПОЛНЕНИЕ';
    if (kind === 'purchase') return 'ПОДПИСКА';
    if (kind === 'refund') return 'ВОЗВРАТ';
    if (kind === 'adjustment') return 'КОРРЕКТИРОВКА';
    return kind.toUpperCase();
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    const fetchBalance = DirectBackendRuntime.fetchBalanceSnapshot;
    if (!fetchBalance) {
      this.balance = '—';
      this.transactions = [];
      this.errorText = 'Баланс недоступен в этой сборке';
      this.loading = false;
      return;
    }
    try {
      const snap = await fetchBalance();
      this.balance = this.formatUsd(snap.usdCents);
      this.transactions = snap.transactions.map((tx: DirectBalanceTransaction) => this.mapTx(tx));
    } catch (err) {
      this.balance = '—';
      this.transactions = [];
      const message = err instanceof Error ? err.message : `${err}`;
      this.errorText = message.length > 0 ? message : 'Не удалось загрузить баланс';
    } finally {
      this.loading = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        this.chrome('АККАУНТ / БАЛАНС', 'Баланс', 'Средства для быстрых покупок VPN Direct', this.onClose);

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor(DirectTheme.muted)
            .width('100%')
            .padding(12)
            .border({ width: 1, color: DirectTheme.line })
            .margin({ bottom: 12 });
        }

        // Ink hero — ДОСТУПНО amount 31 mono white, acid stroke
        Column() {
          Text('ДОСТУПНО')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor('#6BFFFFFF')
            .fontFamily('monospace');
          Text(this.loading ? '…' : this.balance)
            .fontSize(31)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.white)
            .fontFamily('monospace')
            .margin({ top: 10 })
            .maxLines(2);
          Text('Можно использовать без повторной оплаты при покупке подписки.')
            .fontSize(10)
            .fontColor('#7AFFFFFF')
            .margin({ top: 10 });
        }
          .width('100%')
          .padding(17)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(DirectTheme.ink)
          .border({ width: 1, color: '#B3A8F069' })
          .margin({ top: 23 });

        // Top-up H50
        Row() {
          Text('Пополнить баланс')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid);
          Blank();
          Text('+').fontSize(14).fontColor(DirectTheme.acid);
        }
          .width('100%')
          .height(DirectTheme.balanceTopUpHeight)
          .padding({ left: 15, right: 15 })
          .backgroundColor(DirectTheme.ink)
          .margin({ top: 12 })
          .onClick(() => {
            DirectHaptics.selection();
            this.onFlow(DirectFlow.BalanceTopUp);
          });

        Row() {
          Text('ИСТОРИЯ БАЛАНСА')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace');
          Blank();
          Text(String(this.transactions.length).padStart(2, '0'))
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.green)
            .fontFamily('monospace');
        }
          .width('100%')
          .height(38)
          .margin({ top: 23 })
          .border({ width: { top: 1 }, color: DirectTheme.ink });

        if (this.transactions.length === 0) {
          Text('Операций пока нет. Пополнение и покупки через баланс появятся здесь.')
            .fontSize(10)
            .fontColor(DirectTheme.muted)
            .width('100%')
            .padding({ top: 18, bottom: 18 });
        } else {
          ForEach(this.transactions, (tx: BalanceTransactionData) => {
            this.transaction(tx);
          });
        }
      }.padding({ left: 20, right: 20, bottom: 28, top: DirectTheme.pageTop });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private chrome(kicker: string, title: string, subtitle: string, onClose: () => void) {
    Row() {
      Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36)
        .onClick(() => {
          DirectHaptics.navigation();
          onClose();
        });
      Column() {
        Text(kicker).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
        Text(title)
          .fontSize(DirectTypography.pageTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.ink)
          .margin({ top: 6 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
    }.width('100%').height(54);
    Text(subtitle).fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 0 });
  }

  @Builder
  private transaction(tx: BalanceTransactionData) {
    Row() {
      Text(tx.debit ? '−' : '+')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(tx.debit ? DirectTheme.danger : DirectTheme.green)
        .fontFamily('monospace')
        .width(40)
        .textAlign(TextAlign.Center);
      Column() {
        Text(tx.title).fontSize(12).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).maxLines(1);
        Row() {
          Text(this.kindLabel(tx.kind))
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace');
          Text(tx.date)
            .fontSize(9)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace')
            .margin({ left: 6 });
        }.margin({ top: 4 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Text(tx.amount)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.ink)
        .fontFamily('monospace');
    }
      .width('100%')
      .constraintSize({ minHeight: 62 })
      .border({ width: { bottom: 1 }, color: DirectTheme.line });
  }
}

@Component
struct DirectBalanceTopUpParity {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State selected: number = 2;
  @State pending: boolean = false;
  private readonly amounts: string[] = ['$5', '$10', '$25', '$50'];

  build() {
    Column() {
      Row() {
        Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36)
          .onClick(() => {
            DirectHaptics.navigation();
            this.onClose();
          });
        Column() {
          Text('АККАУНТ / БАЛАНС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Text('Пополнение')
            .fontSize(DirectTypography.pageTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .margin({ top: 6 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      }.width('100%').height(54);
      Text('Выберите сумму для баланса').fontSize(13).fontColor(DirectTheme.muted).margin({ bottom: 18 });
      Row() {
        ForEach(this.amounts, (amount: string, index: number) => {
          Text(amount).fontSize(11).fontWeight(FontWeight.Bold).fontFamily('monospace')
            .fontColor(this.selected === index ? DirectTheme.acid : DirectTheme.ink)
            .layoutWeight(1).height(48).textAlign(TextAlign.Center)
            .backgroundColor(this.selected === index ? DirectTheme.ink : Color.Transparent)
            .border({ width: 1, color: DirectTheme.line })
            .onClick(() => {
              this.selected = index;
              DirectHaptics.selection();
            });
        });
      }.width('100%');
      Column() {
        Text('ПОПОЛНЕНИЕ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
        Text('Платёжный адаптер Harmony').fontSize(14).fontColor(DirectTheme.ink).margin({ top: 7 });
        Text(this.pending ? 'Ожидание результата транзакции…' :
          'UI готов; реальная транзакция не имитируется до подключения Store/payment adapter.')
          .fontSize(10).fontColor(DirectTheme.muted).margin({ top: 5 });
      }.width('100%').padding(16).border({ width: 1, color: DirectTheme.line }).margin({ top: 18 });
      Row() {
        Text(this.pending ? 'ОЖИДАНИЕ' : 'ПРОДОЛЖИТЬ')
          .fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace');
        Blank();
        Text('→').fontColor(DirectTheme.acid);
      }
        .width('100%')
        .height(DirectTheme.balanceTopUpHeight)
        .padding({ left: 15, right: 15 })
        .backgroundColor(DirectTheme.ink)
        .margin({ top: 12 })
        .onClick(() => {
          this.pending = true;
          DirectHaptics.selection();
        });
      Blank().layoutWeight(1);
    }.padding({ left: 20, right: 20, top: 18, bottom: 24 }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}
