import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectBackendRuntime, DirectCheckoutQuoteRequest } from '../backend/DirectBackendRuntime';

interface PlanViewData { id: string; name: string; subtitle: string; traffic: string; devices: string; badge: string; price: string; tariffId: number; }

const FALLBACK_PLANS: PlanViewData[] = [
  { id: 'travel', name: 'TRAVEL', subtitle: 'Для коротких поездок', traffic: '—', devices: '—', badge: '', price: '—', tariffId: -1 },
  { id: 'start', name: 'START', subtitle: 'Для одного устройства', traffic: '—', devices: '1', badge: '', price: '—', tariffId: -1 },
  { id: 'plus', name: 'PLUS', subtitle: 'Оптимальный вариант', traffic: '—', devices: '3', badge: 'ПОПУЛЯРНЫЙ', price: '—', tariffId: -1 },
  { id: 'pro', name: 'PRO', subtitle: 'Для нескольких устройств', traffic: '—', devices: '5', badge: '', price: '—', tariffId: -1 },
  { id: 'max', name: 'MAX', subtitle: 'Большой запас трафика', traffic: '—', devices: '10', badge: '', price: '—', tariffId: -1 },
  { id: 'ultra', name: 'ULTRA', subtitle: 'Максимальная конфигурация', traffic: '∞', devices: '20', badge: 'UNLIMITED', price: '—', tariffId: -1 }
];
const PERIODS: number[] = [7, 30, 90, 180, 365];

function field(row: Object, key: string): Object | undefined { return (row as Record<string, Object>)[key]; }
function str(row: Object, key: string): string { const v = field(row, key); return typeof v === 'string' ? v : ''; }
function num(row: Object, key: string): number { const v = field(row, key); return typeof v === 'number' && !Number.isNaN(v) ? v : -1; }

@Component
export struct DirectPlanParityV2Host {
  @Prop flow: DirectFlow = DirectFlow.Plans;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() { if (this.flow === DirectFlow.Constructor) DirectConstructorParityV2({ onClose: this.onClose, onFlow: this.onFlow }); else DirectPlansParityV2({ onClose: this.onClose, onFlow: this.onFlow }); }
}

@Component
struct DirectPlansParityV2 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State periodIndex: number = 1;
  @State plans: PlanViewData[] = FALLBACK_PLANS;

  aboutToAppear(): void { void this.load(); }

  private async load(): Promise<void> {
    try {
      const catalog = await DirectBackendRuntime.fetchAppCatalog();
      if (catalog.tariffs.length === 0) return;
      const mapped: PlanViewData[] = [];
      for (let i = 0; i < catalog.tariffs.length; i++) {
        const row = catalog.tariffs[i];
        const name = str(row, 'name');
        const trafficGb = num(row, 'traffic_gb') >= 0 ? num(row, 'traffic_gb') : num(row, 'trafficGB');
        mapped.push({
          id: `tariff_${num(row, 'id') >= 0 ? num(row, 'id') : i}`,
          name: name.length > 0 ? name.toUpperCase() : 'ТАРИФ',
          subtitle: str(row, 'description') || 'VPN Direct',
          traffic: trafficGb < 0 ? '—' : trafficGb >= 1000 ? `${Math.round(trafficGb / 1000)} TB` : `${trafficGb} GB`,
          devices: num(row, 'devices') >= 0 ? String(num(row, 'devices')) : '—',
          badge: str(row, 'badge'),
          price: num(row, 'price') >= 0 ? `${num(row, 'price')} ${catalog.currency}` : '—',
          tariffId: num(row, 'id')
        });
      }
      if (mapped.length > 0) this.plans = mapped;
    } catch { /* fail closed: UI remains usable, price stays — */ }
  }

  private choose(plan: PlanViewData): void {
    AppStorage.setOrCreate<string>('pending_plan_name', plan.name);
    AppStorage.setOrCreate<string>('pending_plan_price', plan.price);
    AppStorage.setOrCreate<number>('pending_plan_id', plan.tariffId);
    AppStorage.setOrCreate<number>('pending_plan_days', PERIODS[this.periodIndex]);
    DirectHaptics.selection();
    this.onFlow(DirectFlow.Payment);
  }

  build() {
    Scroll() {
      Column() {
        this.chrome('DIRECT / ТАРИФЫ', 'VPN Direct', 'Готовые пресеты или свой набор лимитов');
        Text('СРОК').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ bottom: 8 });
        Row() { ForEach(PERIODS, (days: number, index: number) => Text(days === 7 ? '7 ДНЕЙ' : `${days / 30} МЕС`).fontSize(8).fontWeight(FontWeight.Bold).fontColor(this.periodIndex === index ? DirectTheme.paper : DirectTheme.ink).fontFamily('monospace').layoutWeight(1).height(40).textAlign(TextAlign.Center).backgroundColor(this.periodIndex === index ? DirectTheme.ink : Color.Transparent).border({ width: 1, color: this.periodIndex === index ? DirectTheme.ink : DirectTheme.line }).onClick(() => { this.periodIndex = index; DirectHaptics.selection(); })); }.width('100%');
        Column() { ForEach(this.plans, (plan: PlanViewData) => this.planCard(plan), (plan: PlanViewData) => plan.id); }.width('100%').margin({ top: 16 });
        Row() { Column() { Text('НЕ НАШЛИ ПОДХОДЯЩИЙ?').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Собрать свой тариф').fontSize(13).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('↗').fontSize(13).fontColor(DirectTheme.ink); }.width('100%').height(60).padding(13).border({ width: 1, color: DirectTheme.line }).margin({ top: 14, bottom: 24 }).onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.Constructor); });
      }.padding({ left: 20, right: 20, bottom: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private chrome(kicker: string, title: string, subtitle: string) {
    Row() { Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); Column() { Text(kicker).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(title).fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 6 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); }.width('100%').height(54); Text(subtitle).fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 18 });
  }

  @Builder private planCard(plan: PlanViewData) {
    Column() {
      Row() { Column() { Row() { Text(plan.name).fontSize(20).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); if (plan.badge.length > 0) Text(plan.badge).fontSize(6).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').padding({ left: 6, right: 6, top: 5, bottom: 5 }).backgroundColor(DirectTheme.acid).margin({ left: 7 }); } Text(plan.subtitle).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { Text(plan.price).fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text(PERIODS[this.periodIndex] === 7 ? '/ 7 дней' : '/ период').fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 2 }); }.alignItems(HorizontalAlign.End); }.width('100%');
      Row() { this.fact('ТРАФИК', plan.traffic); this.fact('УСТРОЙСТВА', plan.devices); this.fact('ДНИ', String(PERIODS[this.periodIndex])); }.width('100%').padding({ top: 11, bottom: 11 }).border({ width: { top: 1 }, color: DirectTheme.line }).margin({ top: 11 });
      Row() { Text('ПРОДОЛЖИТЬ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontSize(12).fontColor(DirectTheme.acid); }.width('100%').height(44).padding({ left: 13, right: 13 }).backgroundColor(DirectTheme.ink).margin({ top: 12 }).onClick(() => this.choose(plan));
    }.width('100%').padding(14).border({ width: plan.name === 'PLUS' ? 1.5 : 1, color: plan.name === 'PLUS' ? DirectTheme.ink : DirectTheme.line }).margin({ bottom: 10 });
  }

  @Builder private fact(label: string, value: string) { Column() { Text(label).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(value).fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 4 }); }.layoutWeight(1).alignItems(HorizontalAlign.Start); }
}

@Component
struct DirectConstructorParityV2 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State daysIndex: number = 1;
  @State devicesIndex: number = 1;
  @State trafficIndex: number = 1;
  @State price: string = '—';
  @State quoting: boolean = false;
  private readonly days: number[] = [7, 30, 90, 180, 365];
  private readonly devices: number[] = [1, 3, 5, 10, 20];
  private readonly traffic: number[] = [100, 300, 700, 2000, 0];

  aboutToAppear(): void { void this.quote(); }

  private async quote(): Promise<void> {
    const fn = DirectBackendRuntime.quoteCheckout;
    if (!fn) { this.price = '—'; return; }
    this.quoting = true;
    try {
      const req: DirectCheckoutQuoteRequest = { productKind: 'constructor', days: this.days[this.daysIndex], devices: this.devices[this.devicesIndex], trafficGb: this.traffic[this.trafficIndex] === 0 ? -1 : this.traffic[this.trafficIndex] };
      const result = await fn(req);
      this.price = result.amount === undefined ? '—' : `${result.amount} ${result.currency ?? 'RUB'}`;
    } catch { this.price = '—'; } finally { this.quoting = false; }
  }

  private choose(kind: string, index: number): void { if (kind === 'days') this.daysIndex = index; else if (kind === 'devices') this.devicesIndex = index; else this.trafficIndex = index; void this.quote(); DirectHaptics.selection(); }

  private proceed(): void {
    AppStorage.setOrCreate<number>('constructor_days', this.days[this.daysIndex]);
    AppStorage.setOrCreate<number>('constructor_devices', this.devices[this.devicesIndex]);
    AppStorage.setOrCreate<number>('constructor_traffic_gb', this.traffic[this.trafficIndex]);
    AppStorage.setOrCreate<string>('constructor_price', this.price);
    AppStorage.setOrCreate<string>('pending_plan_name', 'Конструктор VPN Direct');
    AppStorage.setOrCreate<string>('pending_plan_price', this.price);
    DirectHaptics.selection();
    this.onFlow(DirectFlow.Payment);
  }

  build() {
    Scroll() { Column() {
      Row() { Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); Column() { Text('DIRECT / CONSTRUCTOR').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Собрать свой тариф').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 6 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); }.width('100%').height(54);
      Text('ДНИ · УСТРОЙСТВА · ТРАФИК').fontSize(13).fontColor(DirectTheme.muted).margin({ bottom: 18 });
      this.option('СРОК', this.days, this.daysIndex, (i: number) => this.choose('days', i), (v: number) => `${v} ДНЕЙ`);
      this.option('УСТРОЙСТВА', this.devices, this.devicesIndex, (i: number) => this.choose('devices', i), (v: number) => String(v));
      this.option('ТРАФИК', this.traffic, this.trafficIndex, (i: number) => this.choose('traffic', i), (v: number) => v === 0 ? '∞' : v >= 1000 ? `${v / 1000} TB` : `${v} GB`);
      Row() { Text('РАСЧЁТ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text(this.quoting ? '…' : this.price).fontSize(20).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').height(58).border({ width: { top: 1, bottom: 1 }, color: DirectTheme.line }).margin({ top: 18 });
      Row() { Text('ПРОДОЛЖИТЬ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontColor(DirectTheme.acid); }.width('100%').height(52).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).margin({ top: 12 }).onClick(() => this.proceed());
      Blank().height(24);
    }.padding({ left: 20, right: 20 }); }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private option(label: string, values: number[], selected: number, onSelect: (index: number) => void, display: (value: number) => string) {
    Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 12, bottom: 8 });
    Row() { ForEach(values, (value: number, index: number) => Text(display(value)).fontSize(9).fontWeight(FontWeight.Bold).fontColor(selected === index ? DirectTheme.paper : DirectTheme.ink).fontFamily('monospace').layoutWeight(1).height(42).textAlign(TextAlign.Center).backgroundColor(selected === index ? DirectTheme.ink : Color.Transparent).border({ width: 1, color: selected === index ? DirectTheme.ink : DirectTheme.line }).onClick(() => onSelect(index))); }.width('100%');
  }
}
