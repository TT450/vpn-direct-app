import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlows';

interface DirectPlanPresetData {
  id: string;
  name: string;
  tagline: string;
  trafficGB: number;
  unlimited: boolean;
  whitelistGB: number;
  devices: number;
  defaultDays: number;
  featured: boolean;
}

const PRESETS: DirectPlanPresetData[] = [
  { id: 'travel', name: 'Travel', tagline: 'VPN на неделю · поездка или временный доступ', trafficGB: 30, unlimited: false, whitelistGB: 10, devices: 1, defaultDays: 7, featured: false },
  { id: 'start', name: 'Start', tagline: 'Для одного устройства', trafficGB: 100, unlimited: false, whitelistGB: 20, devices: 1, defaultDays: 30, featured: false },
  { id: 'plus', name: 'Plus', tagline: 'Оптимальный выбор для большинства', trafficGB: 300, unlimited: false, whitelistGB: 50, devices: 3, defaultDays: 30, featured: true },
  { id: 'pro', name: 'Pro', tagline: 'Для активного использования', trafficGB: 700, unlimited: false, whitelistGB: 100, devices: 5, defaultDays: 30, featured: false },
  { id: 'max', name: 'Max', tagline: 'Для семьи / команды', trafficGB: 2000, unlimited: false, whitelistGB: 250, devices: 10, defaultDays: 30, featured: false },
  { id: 'ultra', name: 'Ultra', tagline: 'Максимальный пакет без лимита трафика', trafficGB: 0, unlimited: true, whitelistGB: 500, devices: 20, defaultDays: 30, featured: false }
];

const PRESET_DAYS: number[] = [30, 90, 180, 365];
const CONSTRUCTOR_DAYS: number[] = [7, 14, 30, 90, 180, 365];
const CONSTRUCTOR_DEVICES: number[] = [1, 3, 5, 10, 20];
const CONSTRUCTOR_TRAFFIC: number[] = [50, 100, 300, 500, 1000, 2000, 0];
const CONSTRUCTOR_WHITELIST: number[] = [0, 20, 50, 100, 250, 500];

function trafficLabel(gb: number, unlimited: boolean = false): string {
  if (unlimited) return 'Unlimited';
  if (gb >= 1000 && gb % 1000 === 0) return String(gb / 1000) + ' TB';
  return String(gb) + ' GB';
}

function periodLabel(days: number): string {
  if (days === 7) return '7 дней';
  if (days === 14) return '14 дней';
  if (days === 30) return '30 дней';
  if (days === 90) return '90 дней';
  if (days === 180) return '180 дней';
  if (days === 365) return '365 дней';
  return String(days) + ' дн';
}

@Component
export struct DirectPlanParityHost {
  @Prop flow: DirectFlow = DirectFlow.Plans;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

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
struct DirectPlansParity {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State selectedPreset: number = 2;
  @State selectedDays: number = 30;

  build() {
    Scroll() {
      Column() {
        DirectPlanChrome({ kicker: 'DIRECT / ТАРИФЫ', title: 'VPN Direct', subtitle: 'Готовые пресеты или свой набор лимитов', onClose: this.onClose });
        Text('ГОТОВЫЕ ТАРИФЫ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ bottom: 8 });
        ForEach(PRESETS, (preset: DirectPlanPresetData, index: number) => {
          this.presetCard(preset, index);
        });
        Text('СРОК').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ top: 20, bottom: 8 });
        Row() {
          ForEach(PRESET_DAYS, (days: number) => {
            this.periodChip(days);
          });
        }.width('100%');
        Row() {
          Column() {
            Text('НЕ НАШЛИ ПОДХОДЯЩИЙ?').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
            Text('Собрать свой тариф').fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 4 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Text('↗').fontSize(13).fontColor(DirectTheme.ink);
        }.width('100%').height(60).padding(13).border({ width: 1, color: DirectTheme.line }).margin({ top: 14 })
          .onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.Constructor); });
        Row() {
          Text('Продолжить').fontSize(11).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace');
          Blank(); Text('→').fontSize(13).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid);
        }.width('100%').height(52).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 10 })
          .onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.Payment); });
        Blank().height(24);
      }.padding({ left: 20, right: 20, bottom: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private presetCard(preset: DirectPlanPresetData, index: number) {
    const selected = this.selectedPreset === index;
    Column() {
      Row() {
        Column() {
          Row() {
            Text(preset.name.toUpperCase()).fontSize(16).fontWeight(FontWeight.Medium).fontColor(selected ? Color.White : DirectTheme.ink).fontFamily('monospace');
            if (preset.featured) Text('★ ПОПУЛЯРНЫЙ').fontSize(6).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').backgroundColor(DirectTheme.ink).padding({ left: 6, right: 6, top: 5, bottom: 5 }).margin({ left: 7 });
          }
          Text(preset.tagline).fontSize(11).fontColor(selected ? Color.White : DirectTheme.muted).opacity(selected ? 0.55 : 1).margin({ top: 6 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Text(selected ? '●' : '○').fontSize(14).fontColor(selected ? DirectTheme.green : DirectTheme.muted);
      }.width('100%');
      Row() {
        this.stat('ТРАФИК', trafficLabel(preset.trafficGB, preset.unlimited), selected);
        this.stat('УСТР.', String(preset.devices), selected);
        this.stat('ДНИ', String(preset.defaultDays), selected);
      }.width('100%').padding({ top: 12, bottom: 10 });
    }.width('100%').padding(14).backgroundColor(selected ? DirectTheme.panel : Color.White).border({ width: 1, color: selected ? DirectTheme.green : DirectTheme.line }).margin({ bottom: 8 })
      .onClick(() => { this.selectedPreset = index; this.selectedDays = preset.defaultDays; DirectHaptics.selection(); });
  }

  @Builder
  private stat(label: string, value: string, dark: boolean) {
    Column() {
      Text(label).fontSize(8).fontWeight(FontWeight.Bold).fontColor(dark ? Color.White : DirectTheme.muted).opacity(dark ? 0.42 : 1).fontFamily('monospace');
      Text(value).fontSize(12).fontWeight(FontWeight.Medium).fontColor(dark ? Color.White : DirectTheme.ink).fontFamily('monospace').margin({ top: 5 });
    }.layoutWeight(1).alignItems(HorizontalAlign.Start);
  }

  @Builder
  private periodChip(days: number) {
    const selected = this.selectedDays === days;
    Text(periodLabel(days)).fontSize(10).fontWeight(FontWeight.Bold).fontColor(selected ? DirectTheme.acid : DirectTheme.ink).fontFamily('monospace')
      .layoutWeight(1).height(48).textAlign(TextAlign.Center).backgroundColor(selected ? DirectTheme.ink : Color.Transparent)
      .border({ width: 1, color: selected ? DirectTheme.ink : DirectTheme.line })
      .onClick(() => { this.selectedDays = days; DirectHaptics.selection(); });
  }
}

@Component
struct DirectConstructorParity {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State days: number = 30;
  @State devices: number = 3;
  @State trafficIndex: number = 1;
  @State whitelistIndex: number = 0;

  build() {
    Scroll() {
      Column() {
        DirectPlanChrome({ kicker: 'DIRECT / КОНСТРУКТОР', title: 'Собрать свой тариф', subtitle: 'СВОЙ НАБОР ЛИМИТОВ', onClose: this.onClose });
        this.section('СРОК');
        this.chips(PERIOD_LABELS, this.daysIndex(), (index: number) => { this.days = CONSTRUCTOR_DAYS[index]; });
        this.section('УСТРОЙСТВА');
        this.chips(NUMBER_LABELS, this.devicesIndex(), (index: number) => { this.devices = CONSTRUCTOR_DEVICES[index]; });
        this.section('ТРАФИК');
        this.chips(TRAFFIC_LABELS, this.trafficIndex, (index: number) => { this.trafficIndex = index; });
        this.section('WHITE-LIST');
        this.chips(WHITELIST_LABELS, this.whitelistIndex, (index: number) => { this.whitelistIndex = index; });
        Column() {
          Text('ВАША КОНФИГУРАЦИЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(Color.White).opacity(0.42).fontFamily('monospace');
          Text('Свой тариф').fontSize(20).fontWeight(FontWeight.Medium).fontColor(Color.White).margin({ top: 6 });
          Text(String(this.days) + ' дн · ' + String(this.devices) + ' устр. · ' + trafficLabel(CONSTRUCTOR_TRAFFIC[this.trafficIndex], CONSTRUCTOR_TRAFFIC[this.trafficIndex] === 0) + (CONSTRUCTOR_WHITELIST[this.whitelistIndex] > 0 ? ' · ' + String(CONSTRUCTOR_WHITELIST[this.whitelistIndex]) + ' GB WL' : '')).fontSize(10).fontColor(Color.White).opacity(0.48).margin({ top: 5 });
        }.width('100%').padding(16).backgroundColor(DirectTheme.panel).margin({ top: 18 });
        Row() { Text('РАСЧЁТ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text('—').fontSize(20).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').height(58).border({ width: { top: 1, bottom: 1 }, color: DirectTheme.line });
        Row() { Text('ПРОДОЛЖИТЬ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontSize(13).fontColor(DirectTheme.acid); }.width('100%').height(52).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 12 })
          .onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.Payment); });
        Blank().height(28);
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private section(title: string) {
    Text(title).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 12, bottom: 8 });
  }

  @Builder
  private chips(labels: string[], selected: number, onSelect: (index: number) => void) {
    Row() {
      ForEach(labels, (label: string, index: number) => {
        Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(selected === index ? DirectTheme.acid : DirectTheme.ink).fontFamily('monospace')
          .layoutWeight(1).height(38).textAlign(TextAlign.Center).backgroundColor(selected === index ? DirectTheme.ink : Color.Transparent)
          .border({ width: 1, color: selected === index ? DirectTheme.ink : DirectTheme.line })
          .onClick(() => { onSelect(index); DirectHaptics.selection(); });
      });
    }.width('100%');
  }

  private daysIndex(): number { return Math.max(0, CONSTRUCTOR_DAYS.indexOf(this.days)); }
  private devicesIndex(): number { return Math.max(0, CONSTRUCTOR_DEVICES.indexOf(this.devices)); }
  private trafficIndex(): number { return this.trafficIndex; }
}

const PERIOD_LABELS: string[] = ['7', '14', '30', '90', '180', '365'];
const NUMBER_LABELS: string[] = ['1', '3', '5', '10', '20'];
const TRAFFIC_LABELS: string[] = ['50 GB', '100 GB', '300 GB', '500 GB', '1 TB', '2 TB', 'Unlimited'];
const WHITELIST_LABELS: string[] = ['Без WL', '20 GB', '50 GB', '100 GB', '250 GB', '500 GB'];
