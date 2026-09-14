import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectBackendRuntime, DirectCheckoutQuoteRequest } from '../backend/DirectBackendRuntime';

@Component
export struct DirectPaymentParityV2 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @StorageProp('constructor_days') private days: number = 30;
  @StorageProp('constructor_devices') private devices: number = 1;
  @StorageProp('constructor_traffic_gb') private trafficGb: number = 100;
  @StorageProp('pending_plan_name') private planName: string = '';
  @StorageProp('pending_plan_price') private pendingPrice: string = '—';
  @StorageProp('constructor_price') private constructorPrice: string = '—';
  @StorageProp('SESSION_BALANCE_CENTS') private balanceCents: number = 0;
  @State method: number = 0;
  @State amount: string = '—';
  @State title: string = '';
  @State loading: boolean = false;
  @State errorText: string = '';

  aboutToAppear(): void {
    this.amount = this.constructorPrice !== '—' ? this.constructorPrice : this.pendingPrice;
    this.title = this.planName.length > 0 ? this.planName : `${this.days} дн · ${this.devices} устр · ${this.trafficLabel()}`;
    void this.quote();
  }

  private trafficLabel(): string {
    if (this.trafficGb < 0) return '∞';
    if (this.trafficGb >= 1000) return `${Math.round(this.trafficGb / 1000)} TB`;
    return `${this.trafficGb} GB`;
  }

  private balanceLabel(): string {
    return `$${(this.balanceCents / 100).toFixed(2)}`;
  }

  private async quote(): Promise<void> {
    const hook = DirectBackendRuntime.quoteCheckout;
    if (!hook) return;
    this.loading = true;
    try {
      const req: DirectCheckoutQuoteRequest = { productKind: 'constructor', days: this.days, devices: this.devices, trafficGb: this.trafficGb < 0 ? -1 : this.trafficGb };
      const result = await hook(req);
      if (result.amount !== undefined) this.amount = `${result.amount} ${result.currency ?? '₽'}`;
      if (result.planName && result.planName.length > 0) this.title = result.planName;
    } catch (err) {
      this.errorText = err instanceof Error ? err.message : `${err}`;
    } finally { this.loading = false; }
  }

  private proceed(): void {
    if (this.method === 0) {
      this.errorText = 'Платёжный адаптер баланса ещё не подключён.';
      return;
    }
    if (!DirectBackendRuntime.checkoutStatus) {
      this.errorText = 'Платёжный шлюз ещё не подключён.';
      return;
    }
    DirectHaptics.selection();
    this.onFlow(DirectFlow.PaymentWaiting);
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column() {
            Text('ОФОРМЛЕНИЕ / ОПЛАТА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
            Text('Способ оплаты').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 6 });
            Text('Оплата выбранного тарифа').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 7 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Text('×').fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => this.onClose());
        }.width('100%').padding({ top: 28, bottom: 14 }).border({ width: { bottom: 1 }, color: DirectTheme.line });

        Row() { Text('СПОСОБ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text('02 ВАРИАНТА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }
          .width('100%').height(38).border({ width: { top: 1 }, color: DirectTheme.ink }).margin({ top: 25 });

        this.option(0, 'BAL', 'Оплатить с Баланса', `Баланс: ${this.balanceLabel()}`);
        this.option(1, 'WEB', 'Другие способы', 'Защищённая страница платёжного партнёра');

        if (this.method === 0) {
          Row() {
            Text('BAL').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(42).height(42).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink);
            Text('Баланс').fontSize(12).fontWeight(600).fontColor(DirectTheme.ink).margin({ left: 12 });
            Blank(); Text(this.balanceLabel()).fontSize(13).fontWeight(600).fontFamily('monospace').fontColor(DirectTheme.ink);
          }.width('100%').height(66).padding(12).border({ width: 1, color: DirectTheme.line }).margin({ top: 12 });
        }

        Column() {
          Row() { Column() { Text('ВЫБРАННЫЙ ТАРИФ').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace'); Text(this.title).fontSize(18).fontWeight(600).fontColor(DirectTheme.white).margin({ top: 5 }); Text(`${this.days} дн · ${this.devices} устр · ${this.trafficLabel()}`).fontSize(10).fontColor('#7AFFFFFF').margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(this.amount).fontSize(14).fontWeight(600).fontColor(DirectTheme.acid).fontFamily('monospace'); }
        }.width('100%').constraintSize({ minHeight: 86 }).padding(16).backgroundColor(DirectTheme.panel).margin({ top: 16 });

        if (this.errorText.length > 0) Text(this.errorText).fontSize(10).fontColor(DirectTheme.danger).margin({ top: 10 });

        Row() { Text(this.method === 1 ? 'ОТКРЫТЬ ЗАЩИЩЁННУЮ СТРАНИЦУ' : 'СПИСАТЬ С БАЛАНСА').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontSize(12).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid); }
          .width('100%').height(52).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 14 }).onClick(() => this.proceed());
      }.width('100%').padding({ left: 20, right: 20, bottom: 24 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private option(index: number, mark: string, title: string, subtitle: string) {
    Row() { Text(mark).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(44).height(42).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink); Column() { Text(title).fontSize(13).fontWeight(600).fontColor(DirectTheme.ink); Text(subtitle).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 }); Text(this.method === index ? '●' : '○').fontSize(15).fontColor(this.method === index ? DirectTheme.green : DirectTheme.muted); }
      .width('100%').constraintSize({ minHeight: 74 }).padding({ left: 12, right: 12 }).backgroundColor(this.method === index ? DirectTheme.acidSelected : Color.Transparent).border({ width: 1, color: this.method === index ? DirectTheme.green : DirectTheme.line }).margin({ top: index === 0 ? 0 : 8 }).onClick(() => { this.method = index; DirectHaptics.selection(); });
  }
}
