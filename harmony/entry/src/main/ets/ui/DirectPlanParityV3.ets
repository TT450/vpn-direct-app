import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectBackendRuntime } from '../backend/DirectBackendRuntime';

interface PlanParityItem { id: string; name: string; subtitle: string; traffic: string; devices: string; badge: string; tariffId: number; price: string; }
const DAYS: number[] = [7, 30, 90, 180, 365];
const FALLBACK: PlanParityItem[] = [
  { id: 'start', name: 'START', subtitle: 'Для одного устройства', traffic: '100 GB', devices: '1', badge: '', tariffId: -1, price: '—' },
  { id: 'plus', name: 'PLUS', subtitle: 'Оптимальный вариант', traffic: '300 GB', devices: '3', badge: 'ПОПУЛЯРНЫЙ', tariffId: -1, price: '—' },
  { id: 'pro', name: 'PRO', subtitle: 'Для нескольких устройств', traffic: '700 GB', devices: '5', badge: '', tariffId: -1, price: '—' },
  { id: 'max', name: 'MAX', subtitle: 'Большой запас трафика', traffic: '2 TB', devices: '10', badge: '', tariffId: -1, price: '—' },
  { id: 'ultra', name: 'ULTRA', subtitle: 'Без ограничений по трафику', traffic: '∞', devices: '20', badge: 'UNLIMITED', tariffId: -1, price: '—' }
];
function obj(row: Object, key: string): Object | undefined { return (row as Record<string, Object>)[key]; }
function text(row: Object, key: string): string { const v = obj(row, key); return typeof v === 'string' ? v : ''; }
function number(row: Object, key: string): number { const v = obj(row, key); return typeof v === 'number' && !Number.isNaN(v) ? v : -1; }
function daysTitle(days: number): string { if (days === 7) return '7 дней'; if (days === 30) return '1 мес.'; if (days === 90) return '3 мес.'; if (days === 180) return '6 мес.'; return '1 год'; }

@Component
export struct DirectPlanParityV3Host {
  @Prop flow: DirectFlow = DirectFlow.Plans;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() { if (this.flow === DirectFlow.Constructor) DirectConstructorParityV3({ onClose: this.onClose, onFlow: this.onFlow }); else DirectPlansParityV3({ onClose: this.onClose, onFlow: this.onFlow }); }
}

@Component
struct DirectPlansParityV3 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State periodIndex: number = 1;
  @State plans: PlanParityItem[] = FALLBACK;
  aboutToAppear(): void { void this.loadCatalog(); }
  private async loadCatalog(): Promise<void> {
    try {
      const catalog = await DirectBackendRuntime.fetchAppCatalog();
      if (catalog.tariffs.length === 0) return;
      const mapped: PlanParityItem[] = [];
      for (let i = 0; i < catalog.tariffs.length; i++) {
        const row = catalog.tariffs[i]; const id = number(row, 'id');
        const trafficGb = number(row, 'traffic_gb') >= 0 ? number(row, 'traffic_gb') : number(row, 'trafficGB');
        mapped.push({ id: `tariff_${id >= 0 ? id : i}`, name: (text(row, 'name') || 'ТАРИФ').toUpperCase(), subtitle: text(row, 'description') || 'VPN Direct', traffic: trafficGb < 0 ? '—' : trafficGb >= 1000 ? `${trafficGb / 1000} TB` : `${trafficGb} GB`, devices: number(row, 'devices') >= 0 ? String(number(row, 'devices')) : '—', badge: text(row, 'badge'), tariffId: id, price: number(row, 'price') >= 0 ? `${number(row, 'price')} ${catalog.currency}` : '—' });
      }
      if (mapped.length > 0) this.plans = mapped;
    } catch { }
  }
  private choose(plan: PlanParityItem): void {
    AppStorage.setOrCreate<string>('pending_plan_name', plan.name); AppStorage.setOrCreate<string>('pending_plan_price', plan.price); AppStorage.setOrCreate<number>('pending_plan_id', plan.tariffId); AppStorage.setOrCreate<number>('pending_plan_days', DAYS[this.periodIndex]);
    DirectHaptics.selection(); this.onFlow(DirectFlow.Payment);
  }
  build() {
    Scroll() { Column() {
      Column() { Text('DIRECT / PLANS').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Тарифы').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 5 }); Text('Выберите готовый вариант и подключите его сразу').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 5 }); }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: DirectTheme.pageTop, bottom: 18 });
      Text('ПЕРИОД').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ bottom: 8 });
      Row() { ForEach(DAYS, (d: number, i: number) => Text(daysTitle(d).toUpperCase()).fontSize(9).fontWeight(600).fontColor(this.periodIndex === i ? DirectTheme.paper : DirectTheme.ink).fontFamily('monospace').layoutWeight(1).height(40).textAlign(TextAlign.Center).backgroundColor(this.periodIndex === i ? DirectTheme.ink : Color.Transparent).border({ width: 1, color: this.periodIndex === i ? DirectTheme.ink : DirectTheme.line }).onClick(() => { this.periodIndex = i; DirectHaptics.selection(); })).width('100%');
      Column() { ForEach(this.plans, (plan: PlanParityItem) => this.card(plan), (plan: PlanParityItem) => plan.id); }.width('100%').margin({ top: 16 });
      Row() { Column() { Text('НЕ НАШЛИ ПОДХОДЯЩИЙ?').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Собрать свой тариф').fontSize(13).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('↗').fontSize(13).fontColor(DirectTheme.ink); }.width('100%').height(60).padding(13).border({ width: 1, color: DirectTheme.line }).margin({ top: 14, bottom: 28 }).onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.Constructor); });
    }.padding({ left: 20, right: 20 }); }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  @Builder private card(plan: PlanParityItem) {
    Column() {
      Row() { Column() { Row() { Text(plan.name).fontSize(20).fontWeight(600).fontColor(DirectTheme.ink).fontFamily('monospace'); if (plan.badge.length > 0) Text(plan.badge).fontSize(6).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').padding({ left: 6, right: 6 }).height(20).backgroundColor(DirectTheme.acid).margin({ left: 7 }); }.height(20); Text(plan.subtitle).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { Text(plan.price).fontSize(18).fontWeight(600).fontColor(DirectTheme.ink).fontFamily('monospace'); Text(` / ${daysTitle(DAYS[this.periodIndex])}`).fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 2 }); }.alignItems(HorizontalAlign.End); }.width('100%');
      Row() { this.fact('ТРАФИК', plan.traffic); this.fact('УСТРОЙСТВА', plan.devices); this.fact('ДНИ', String(DAYS[this.periodIndex])); }.width('100%').padding({ top: 11, bottom: 11 }).border({ width: { top: 1 }, color: DirectTheme.line }).margin({ top: 11 });
      Row() { Text('КУПИТЬ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontSize(12).fontColor(DirectTheme.acid); }.width('100%').height(44).padding({ left: 13, right: 13 }).backgroundColor(DirectTheme.ink).onClick(() => this.choose(plan));
    }.width('100%').padding(14).border({ width: plan.id === 'plus' ? 1.5 : 1, color: plan.id === 'plus' ? DirectTheme.ink : DirectTheme.line }).margin({ bottom: 10 });
  }
  @Builder private fact(label: string, value: string) { Column() { Text(label).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(value).fontSize(11).fontWeight(600).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 4 }); }.layoutWeight(1).alignItems(HorizontalAlign.Start); }
}

@Component
struct DirectConstructorParityV3 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State days: number = 30; @State devices: number = 3; @State traffic: number = 300; @State price: string = '—'; @State quoting: boolean = false;
  private readonly dayOptions: number[] = [7, 30, 90, 180, 365]; private readonly deviceOptions: number[] = [1, 3, 5, 10, 20]; private readonly trafficOptions: number[] = [100, 300, 700, 2000, 0];
  aboutToAppear(): void { void this.refreshQuote(); }
  private planName(): string { if (this.traffic === 0 || this.devices >= 20) return 'ULTRA'; if (this.traffic >= 2000 || this.devices >= 10) return 'MAX'; if (this.traffic >= 700 || this.devices >= 5) return 'PRO'; if (this.traffic >= 300 || this.devices >= 3) return 'PLUS'; if (this.days <= 7) return 'TRAVEL'; return 'START'; }
  private daysValue(): string { if (this.days === 365) return '1 год'; if (this.days === 180) return '6 месяцев'; if (this.days === 90) return '3 месяца'; if (this.days === 30) return '1 месяц'; return `${this.days} дней`; }
  private trafficValue(): string { return this.traffic === 0 ? 'Безлимит' : this.traffic >= 1000 ? `${this.traffic / 1000} TB` : `${this.traffic} GB`; }
  private async refreshQuote(): Promise<void> { const fn = DirectBackendRuntime.quoteCheckout; if (!fn) { this.price = '—'; return; } this.quoting = true; try { const q = await fn({ productKind: 'constructor', days: this.days, devices: this.devices, trafficGb: this.traffic === 0 ? -1 : this.traffic }); this.price = q.amount === undefined ? '—' : `${q.amount} ${q.currency ?? 'RUB'}`; } catch { this.price = '—'; } finally { this.quoting = false; } }
  private proceed(): void { AppStorage.setOrCreate<number>('constructor_days', this.days); AppStorage.setOrCreate<number>('constructor_devices', this.devices); AppStorage.setOrCreate<number>('constructor_traffic_gb', this.traffic); AppStorage.setOrCreate<string>('constructor_price', this.price); AppStorage.setOrCreate<string>('pending_plan_name', this.planName()); AppStorage.setOrCreate<string>('pending_plan_price', this.price); DirectHaptics.selection(); this.onFlow(DirectFlow.Payment); }
  build() {
    Scroll() { Column() {
      Column() { Text('DIRECT / CUSTOM').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Конструктор').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 5 }); Text('Настройте подписку под себя').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 5 }); }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: DirectTheme.pageTop, bottom: 15 });
      this.builderSection('Срок', this.daysValue(), this.dayOptions, this.days, (v: number) => { this.days = v; void this.refreshQuote(); }, (v: number) => daysTitle(v));
      this.builderSection('Устройства', String(this.devices), this.deviceOptions, this.devices, (v: number) => { this.devices = v; void this.refreshQuote(); }, (v: number) => String(v));
      this.builderSection('Трафик', this.trafficValue(), this.trafficOptions, this.traffic, (v: number) => { this.traffic = v; void this.refreshQuote(); }, (v: number) => v === 0 ? 'Безлимит' : v >= 1000 ? `${v / 1000} TB` : `${v} GB`);
      Row() { Column() { Text('ВАШ ТАРИФ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(this.planName()).fontSize(20).fontWeight(600).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 3 }); Text(`${this.daysValue()} · ${this.devices} устройства · ${this.trafficValue()}`).fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 5 }).maxLines(1); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(this.quoting ? '…' : this.price).fontSize(25).fontWeight(600).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').margin({ top: 10 });
      Row() { Text('КУПИТЬ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontSize(12).fontColor(DirectTheme.acid); }.width('100%').height(48).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 10 }).onClick(() => this.proceed());
      Blank().height(14);
    }.padding({ left: 20, right: 20, bottom: 14 }); }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  @Builder private builderSection(label: string, value: string, options: number[], selected: number, onSelect: (v: number) => void, labelFor: (v: number) => string) {
    Column() { Row() { Text(label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Blank(); Text(value.toUpperCase()).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); }.width('100%').margin({ bottom: 8 }); Row() { ForEach(options, (v: number) => Text(labelFor(v)).fontSize(9).fontWeight(600).fontColor(selected === v ? DirectTheme.paper : DirectTheme.ink).fontFamily('monospace').layoutWeight(1).height(39).textAlign(TextAlign.Center).backgroundColor(selected === v ? DirectTheme.ink : Color.Transparent).border({ width: 1, color: selected === v ? DirectTheme.ink : DirectTheme.line }).onClick(() => onSelect(v))); }.width('100%'); }.width('100%').padding({ top: 9, bottom: 9 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }
}
