import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectBackendRuntime, DirectCheckoutQuoteRequest } from '../backend/DirectBackendRuntime';

interface DirectPlanPresetData {
  id: string;
  name: string;
  tagline: string;
  traffic: string;
  devices: number;
  badge: string;
  featured: boolean;
  priceHint: string;
}

/** Sales-first catalog matching DirectPlansView fallbackPlans */
const PRESETS: DirectPlanPresetData[] = [
  { id: 'start', name: 'START', tagline: 'Для одного устройства', traffic: '100 GB', devices: 1, badge: '', featured: false, priceHint: '—' },
  { id: 'plus', name: 'PLUS', tagline: 'Оптимальный вариант', traffic: '300 GB', devices: 3, badge: 'ПОПУЛЯРНЫЙ', featured: true, priceHint: '—' },
  { id: 'pro', name: 'PRO', tagline: 'Для нескольких устройств', traffic: '700 GB', devices: 5, badge: '', featured: false, priceHint: '—' },
  { id: 'max', name: 'MAX', tagline: 'Большой запас трафика', traffic: '2 TB', devices: 10, badge: '', featured: false, priceHint: '—' },
  { id: 'ultra', name: 'ULTRA', tagline: 'Без ограничений по трафику', traffic: '∞', devices: 20, badge: 'UNLIMITED', featured: false, priceHint: '—' }
];

interface PeriodOption {
  title: string;
  days: number;
  suffix: string;
}

const PERIODS: PeriodOption[] = [
  { title: '1 мес', days: 30, suffix: '/ мес' },
  { title: '3 мес', days: 90, suffix: '/ 3 мес' },
  { title: '6 мес', days: 180, suffix: '/ 6 мес' },
  { title: '12 мес', days: 365, suffix: '/ год' }
];

function catalogFieldString(row: Object, key: string): string {
  const rec = row as Record<string, Object>;
  const v = rec[key];
  if (typeof v === 'string') {
    return v;
  }
  return '';
}

function catalogFieldNumber(row: Object, key: string): number | null {
  const rec = row as Record<string, Object>;
  const v = rec[key];
  if (typeof v === 'number' && !Number.isNaN(v)) {
    return v;
  }
  return null;
}

function mapCatalogTariff(row: Object, index: number): DirectPlanPresetData {
  const name = catalogFieldString(row, 'name');
  const description = catalogFieldString(row, 'description');
  const price = catalogFieldNumber(row, 'price');
  const devices = catalogFieldNumber(row, 'devices') ?? 1;
  const trafficGb = catalogFieldNumber(row, 'traffic_gb') ?? catalogFieldNumber(row, 'trafficGB');
  const idNum = catalogFieldNumber(row, 'id');
  const id = idNum !== null ? `tariff_${idNum}` : `tariff_${index}`;
  let traffic = '∞';
  if (trafficGb !== null) {
    traffic = trafficGb >= 1000 ? `${Math.floor(trafficGb / 1000)} TB` : `${trafficGb} GB`;
  }
  const badge = catalogFieldString(row, 'badge');
  const featured = name.toUpperCase() === 'PLUS';
  const priceHint = price !== null ? String(price) : '—';
  return {
    id: id,
    name: name.length > 0 ? name : 'Тариф',
    tagline: description.length > 0 ? description : 'VPN Direct',
    traffic: traffic,
    devices: devices,
    badge: badge,
    featured: featured,
    priceHint: priceHint
  };
}

@Component
export struct DirectPlanParityHost {
  @Prop flow: DirectFlow = DirectFlow.Plans;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

  build() {
    if (this.flow === DirectFlow.Constructor) {
      DirectConstructorParity({ onClose: this.onClose, onFlow: this.onFlow });
    } else {
      DirectPlansParity({ onClose: this.onClose, onFlow: this.onFlow });
    }
  }
}

@Component
struct DirectPlanChrome {
  @Prop kicker: string = '';
  @Prop title: string = '';
  @Prop subtitle: string = '';
  onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36)
          .onClick(() => { DirectHaptics.navigation(); this.onClose(); });
        Column() {
          Text(this.kicker).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Text(this.title)
            .fontSize(DirectTypography.pageTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .margin({ top: 6 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      }.width('100%').height(54);
      Text(this.subtitle).fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 18 });
    }.width('100%');
  }
}

@Component
struct DirectPlansParity {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State selectedPeriod: number = 0;
  @State catalogPlans: DirectPlanPresetData[] = [];

  aboutToAppear(): void {
    void this.loadCatalog();
  }

  private async loadCatalog(): Promise<void> {
    try {
      const catalog = await DirectBackendRuntime.fetchAppCatalog();
      const tariffs = catalog.tariffs;
      if (tariffs.length === 0) {
        this.catalogPlans = [];
        return;
      }
      const mapped: DirectPlanPresetData[] = [];
      for (let i = 0; i < tariffs.length; i++) {
        mapped.push(mapCatalogTariff(tariffs[i], i));
      }
      this.catalogPlans = mapped;
    } catch (err) {
      console.warn(`DirectPlansParity: catalog load failed: ${err}`);
      this.catalogPlans = [];
    }
  }

  private displayPlans(): DirectPlanPresetData[] {
    return this.catalogPlans.length > 0 ? this.catalogPlans : PRESETS;
  }

  build() {
    Scroll() {
      Column() {
        DirectPlanChrome({
          kicker: 'DIRECT / PLANS',
          title: 'Тарифы',
          subtitle: 'Выберите готовый вариант и подключите его сразу',
          onClose: this.onClose
        });

        // Period on top H40 — DirectPlansView.periodPicker
        Text('ПЕРИОД')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.ink)
          .fontFamily('monospace')
          .width('100%')
          .margin({ bottom: 8 });
        Row({ space: 6 }) {
          ForEach(PERIODS, (period: PeriodOption, index: number) => {
            Text(period.title)
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.selectedPeriod === index ? DirectTheme.paper : DirectTheme.ink)
              .fontFamily('monospace')
              .layoutWeight(1)
              .height(DirectTheme.periodPickerHeight)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.selectedPeriod === index ? DirectTheme.ink : Color.Transparent)
              .border({
                width: 1,
                color: this.selectedPeriod === index ? DirectTheme.ink : DirectTheme.line
              })
              .onClick(() => {
                this.selectedPeriod = index;
                DirectHaptics.selection();
              });
          });
        }.width('100%');

        Column() {
          ForEach(this.displayPlans(), (preset: DirectPlanPresetData, index: number) => {
            this.planCard(preset, index);
          }, (preset: DirectPlanPresetData) => preset.id);
        }.width('100%').margin({ top: 16 });

        Row() {
          Column() {
            Text('НЕ НАШЛИ ПОДХОДЯЩИЙ?')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.muted)
              .fontFamily('monospace');
            Text('Собрать свой тариф')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .margin({ top: 4 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Text('↗').fontSize(13).fontColor(DirectTheme.ink);
        }
          .width('100%')
          .height(60)
          .padding(13)
          .border({ width: 1, color: DirectTheme.line })
          .margin({ top: 14, bottom: 28 })
          .onClick(() => {
            DirectHaptics.navigation();
            this.onFlow(DirectFlow.Constructor);
          });
      }.padding({ left: 20, right: 20, bottom: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private planCard(preset: DirectPlanPresetData, index: number) {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(preset.name)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
            if (preset.badge.length > 0) {
              Text(preset.badge)
                .fontSize(6)
                .fontWeight(FontWeight.Bold)
                .fontColor(DirectTheme.ink)
                .fontFamily('monospace')
                .padding({ left: 6, right: 6 })
                .height(20)
                .textAlign(TextAlign.Center)
                .backgroundColor(DirectTheme.acid)
                .margin({ left: 7 });
            }
          }
          Text(preset.tagline).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 4 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Column() {
          Text(preset.priceHint)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace');
          Text(PERIODS[this.selectedPeriod].suffix)
            .fontSize(9)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace')
            .margin({ top: 2 });
        }.alignItems(HorizontalAlign.End);
      }.width('100%');

      Row().width('100%').height(1).backgroundColor(DirectTheme.line).margin({ top: 11, bottom: 11 });

      Row() {
        this.fact('ТРАФИК', preset.traffic);
        this.fact('УСТРОЙСТВА', String(preset.devices));
        this.fact('ДНИ', String(PERIODS[this.selectedPeriod].days));
      }.width('100%');

      Row() {
        Text('КУПИТЬ')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.acid)
          .fontFamily('monospace');
        Blank();
        Text('→').fontSize(12).fontColor(DirectTheme.acid);
      }
        .width('100%')
        .height(44)
        .padding({ left: 13, right: 13 })
        .backgroundColor(DirectTheme.ink)
        .margin({ top: 12 })
        .onClick(() => {
          DirectHaptics.selection();
          this.onFlow(DirectFlow.Payment);
        });
    }
      .width('100%')
      .padding(14)
      .border({
        width: preset.featured ? 1.5 : 1,
        color: preset.featured ? DirectTheme.ink : DirectTheme.line
      })
      .margin({ bottom: 10 });
  }

  @Builder
  private fact(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(8)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.muted)
        .fontFamily('monospace');
      Text(value)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(DirectTheme.ink)
        .fontFamily('monospace')
        .margin({ top: 4 });
    }.layoutWeight(1).alignItems(HorizontalAlign.Start);
  }
}

@Component
struct DirectConstructorParity {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  // iOS-matching options: days [7,30,90,180,365], devices [1,3,5,10,20], traffic [100,300,700,2000,0=∞]
  @State daysIndex: number = 1;    // 30 days default
  @State devicesIndex: number = 1; // 3 devices default
  @State trafficIndex: number = 1; // 300 GB default
  @State quotedPrice: string = '—';
  @State quoteLoading: boolean = false;

  private readonly dayLabels: string[] = ['7', '30', '90', '180', '365'];
  private readonly dayValues: number[] = [7, 30, 90, 180, 365];
  private readonly deviceLabels: string[] = ['1', '3', '5', '10', '20'];
  private readonly deviceValues: number[] = [1, 3, 5, 10, 20];
  private readonly trafficLabels: string[] = ['100 GB', '300 GB', '700 GB', '2 TB', '∞'];
  private readonly trafficValues: number[] = [100, 300, 700, 2000, 0];

  aboutToAppear(): void {
    void this.updateQuote();
  }

  private async updateQuote(): Promise<void> {
    this.quoteLoading = true;
    const days = this.dayValues[this.daysIndex];
    const devices = this.deviceValues[this.devicesIndex];
    const trafficGb = this.trafficValues[this.trafficIndex];
    if (DirectBackendRuntime.quoteCheckout !== null) {
      try {
        const req: DirectCheckoutQuoteRequest = {
          productKind: 'constructor',
          days: days,
          devices: devices,
          trafficGb: trafficGb === 0 ? -1 : trafficGb
        };
        const quote = await DirectBackendRuntime.quoteCheckout(req);
        if (quote.error && quote.error.length > 0) {
          this.quotedPrice = this.localEstimate(days, devices, trafficGb);
        } else if (quote.amount !== undefined) {
          const cur = quote.currency ?? '₽';
          this.quotedPrice = `${quote.amount} ${cur}`;
        } else {
          this.quotedPrice = this.localEstimate(days, devices, trafficGb);
        }
      } catch {
        this.quotedPrice = this.localEstimate(days, devices, trafficGb);
      }
    } else {
      this.quotedPrice = this.localEstimate(days, devices, trafficGb);
    }
    this.quoteLoading = false;
  }

  /** Local price estimate when backend is unavailable. */
  private localEstimate(days: number, devices: number, trafficGb: number): string {
    // Base: 149 ₽/month for 3 devices and 300 GB
    const monthFactor = days / 30;
    const deviceFactor = Math.max(1, devices) / 3;
    const trafficFactor = trafficGb === 0 ? 3.5 : Math.max(0.5, trafficGb / 300);
    const base = 149;
    const estimated = Math.round(base * monthFactor * deviceFactor * trafficFactor);
    return `~${estimated} ₽`;
  }

  private selectDay(i: number): void {
    this.daysIndex = i;
    DirectHaptics.selection();
    void this.updateQuote();
  }

  private selectDevice(i: number): void {
    this.devicesIndex = i;
    DirectHaptics.selection();
    void this.updateQuote();
  }

  private selectTraffic(i: number): void {
    this.trafficIndex = i;
    DirectHaptics.selection();
    void this.updateQuote();
  }

  private purchaseConstructor(): void {
    // Persist selection for payment page
    AppStorage.setOrCreate('constructor_days', this.dayValues[this.daysIndex]);
    AppStorage.setOrCreate('constructor_devices', this.deviceValues[this.devicesIndex]);
    AppStorage.setOrCreate('constructor_traffic_gb', this.trafficValues[this.trafficIndex]);
    AppStorage.setOrCreate('constructor_price', this.quotedPrice);
    DirectHaptics.selection();
    this.onFlow(DirectFlow.Payment);
  }

  build() {
    Scroll() {
      Column() {
        DirectPlanChrome({
          kicker: 'DIRECT / КОНСТРУКТОР',
          title: 'Собрать свой тариф',
          subtitle: 'ДНИ · УСТРОЙСТВА · ТРАФИК',
          onClose: this.onClose
        });

        this.section('СРОК (ДНИ)');
        this.chips(this.dayLabels, this.daysIndex, (i: number) => { this.selectDay(i); });

        this.section('УСТРОЙСТВА');
        this.chips(this.deviceLabels, this.devicesIndex, (i: number) => { this.selectDevice(i); });

        this.section('ТРАФИК');
        this.chips(this.trafficLabels, this.trafficIndex, (i: number) => { this.selectTraffic(i); });

        // Config summary card
        Column() {
          Text('ВАША КОНФИГУРАЦИЯ')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor('#6BFFFFFF')
            .fontFamily('monospace');
          Text('Свой тариф')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 6 });
          Text(`${this.dayValues[this.daysIndex]} дн · ${this.deviceValues[this.devicesIndex]} устр · ${this.trafficLabels[this.trafficIndex]}`)
            .fontSize(10)
            .fontColor('#7AFFFFFF')
            .margin({ top: 5 });
        }.width('100%').padding(16).backgroundColor(DirectTheme.panel).margin({ top: 18 });

        // Live price
        Row() {
          Text('РАСЧЁТ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Blank();
          Text(this.quoteLoading ? '…' : this.quotedPrice)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace');
        }.width('100%').height(58).border({ width: { top: 1, bottom: 1 }, color: DirectTheme.line });

        Row() {
          Text('КУПИТЬ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace');
          Blank();
          Text('→').fontColor(DirectTheme.acid);
        }
          .width('100%')
          .height(52)
          .padding({ left: 14, right: 14 })
          .backgroundColor(DirectTheme.ink)
          .margin({ top: 12 })
          .onClick(() => { this.purchaseConstructor(); });

        Blank().height(28);
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private section(title: string) {
    Text(title)
      .fontSize(9)
      .fontWeight(FontWeight.Bold)
      .fontColor(DirectTheme.muted)
      .fontFamily('monospace')
      .margin({ top: 12, bottom: 8 });
  }

  @Builder
  private chips(labels: string[], selected: number, onSelect: (index: number) => void) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(labels, (label: string, index: number) => {
        Text(label)
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(selected === index ? DirectTheme.acid : DirectTheme.ink)
          .fontFamily('monospace')
          .height(38)
          .padding({ left: 12, right: 12 })
          .margin({ right: 6, bottom: 6 })
          .textAlign(TextAlign.Center)
          .backgroundColor(selected === index ? DirectTheme.ink : Color.Transparent)
          .border({ width: 1, color: selected === index ? DirectTheme.ink : DirectTheme.line })
          .onClick(() => { onSelect(index); });
      });
    }.width('100%');
  }
}
