import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';

interface DirectPlanPresetData {
  id: string;
  name: string;
  tagline: string;
  traffic: string;
  whitelist: string;
  devices: number;
  defaultDays: number;
  featured: boolean;
}

const PRESETS: DirectPlanPresetData[] = [
  { id: 'travel', name: 'Travel', tagline: 'VPN на неделю · поездка или временный доступ', traffic: '30 GB', whitelist: '10 GB', devices: 1, defaultDays: 7, featured: false },
  { id: 'start', name: 'Start', tagline: 'Для одного устройства', traffic: '100 GB', whitelist: '20 GB', devices: 1, defaultDays: 30, featured: false },
  { id: 'plus', name: 'Plus', tagline: 'Оптимальный выбор для большинства', traffic: '300 GB', whitelist: '50 GB', devices: 3, defaultDays: 30, featured: true },
  { id: 'pro', name: 'Pro', tagline: 'Для активного использования', traffic: '700 GB', whitelist: '100 GB', devices: 5, defaultDays: 30, featured: false },
  { id: 'max', name: 'Max', tagline: 'Для семьи / команды', traffic: '2 TB', whitelist: '250 GB', devices: 10, defaultDays: 30, featured: false },
  { id: 'ultra', name: 'Ultra', tagline: 'Максимальный пакет без лимита трафика', traffic: 'Unlimited', whitelist: '500 GB', devices: 20, defaultDays: 30, featured: false }
];
const PRESET_DAYS: number[] = [30, 90, 180, 365];
const CONSTRUCTOR_DAYS: number[] = [7, 14, 30, 90, 180, 365];
const CONSTRUCTOR_DEVICES: number[] = [1, 3, 5, 10, 20];
const CONSTRUCTOR_TRAFFIC: string[] = ['50 GB', '100 GB', '300 GB', '500 GB', '1 TB', '2 TB', 'Unlimited'];
const CONSTRUCTOR_WHITELIST: string[] = ['Без White-list', '20 GB', '50 GB', '100 GB', '250 GB', '500 GB'];

function daysLabel(days: number): string {
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
        Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36)
          .onClick(() => { DirectHaptics.navigation(); this.onClose(); });
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
        Text('ГОТОВЫЕ ТАРИФЫ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ bottom: 8 });
        ForEach(PRESETS, (preset: DirectPlanPresetData, index: number) => { this.presetCard(preset, index); });
        Text('СРОК').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 20, bottom: 8 });
        Row() { ForEach(PRESET_DAYS, (days: number) => { this.periodChip(days); }); }.width('100%');
        Row() {
          Column() { Text('НЕ НАШЛИ ПОДХОДЯЩИЙ?').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Собрать свой тариф').fontSize(13).fontColor(DirectTheme.ink).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Text('↗').fontSize(13).fontColor(DirectTheme.ink);
        }.width('100%').height(60).padding(13).border({ width: 1, color: DirectTheme.line }).margin({ top: 14 })
          .onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.Constructor); });
        Row() { Text('ПРОДОЛЖИТЬ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontColor(DirectTheme.acid); }
          .width('100%').height(52).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 10 })
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
        this.stat('ТРАФИК', preset.traffic, selected);
        this.stat('УСТР.', String(preset.devices), selected);
        this.stat('ДНИ', String(preset.defaultDays), selected);
      }.width('100%').padding({ top: 12, bottom: 10 });
      Text(preset.whitelist === 'Без White-list' ? preset.whitelist : 'WHITE-LIST · ' + preset.whitelist).fontSize(8).fontColor(selected ? Color.White : DirectTheme.muted).opacity(selected ? 0.42 : 1).fontFamily('monospace');
    }.width('100%').padding(14).backgroundColor(selected ? DirectTheme.panel : Color.White).border({ width: 1, color: selected ? DirectTheme.green : DirectTheme.line }).margin({ bottom: 8 })
      .onClick(() => { this.selectedPreset = index; this.selectedDays = preset.defaultDays; DirectHaptics.selection(); });
  }

  @Builder
  private stat(label: string, value: string, dark: boolean) {
    Column() { Text(label).fontSize(8).fontWeight(FontWeight.Bold).fontColor(dark ? Color.White : DirectTheme.muted).opacity(dark ? 0.42 : 1).fontFamily('monospace'); Text(value).fontSize(12).fontWeight(FontWeight.Medium).fontColor(dark ? Color.White : DirectTheme.ink).fontFamily('monospace').margin({ top: 5 }); }.layoutWeight(1).alignItems(HorizontalAlign.Start);
  }

  @Builder
  private periodChip(days: number) {
    const selected = this.selectedDays === days;
    Text(daysLabel(days)).fontSize(10).fontWeight(FontWeight.Bold).fontColor(selected ? DirectTheme.acid : DirectTheme.ink).fontFamily('monospace').layoutWeight(1).height(48).textAlign(TextAlign.Center).backgroundColor(selected ? DirectTheme.ink : Color.Transparent).border({ width: 1, color: selected ? DirectTheme.ink : DirectTheme.line }).onClick(() => { this.selectedDays = days; DirectHaptics.selection(); });
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
        DirectPlanChrome({ kicker: 'DIRECT / КОНСТРУКТОР', title: 'Собрать свой тариф', subtitle: 'ДНИ · УСТРОЙСТВА · ТРАФИК · WHITE-LIST', onClose: this.onClose });
        this.section('СРОК'); this.chips(PERIOD_LABELS, CONSTRUCTOR_DAYS.indexOf(this.days), (i: number) => { this.days = CONSTRUCTOR_DAYS[i]; });
        this.section('УСТРОЙСТВА'); this.chips(NUMBER_LABELS, CONSTRUCTOR_DEVICES.indexOf(this.devices), (i: number) => { this.devices = CONSTRUCTOR_DEVICES[i]; });
        this.section('ТРАФИК'); this.chips(TRAFFIC_LABELS, this.trafficIndex, (i: number) => { this.trafficIndex = i; });
        this.section('WHITE-LIST'); this.chips(WHITELIST_LABELS, this.whitelistIndex, (i: number) => { this.whitelistIndex = i; });
        Column() {
          Text('ВАША КОНФИГУРАЦИЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(Color.White).opacity(0.42).fontFamily('monospace');
          Text('Свой тариф').fontSize(20).fontWeight(FontWeight.Medium).fontColor(Color.White).margin({ top: 6 });
          Text(String(this.days) + ' дн · ' + String(this.devices) + ' устр. · ' + CONSTRUCTOR_TRAFFIC[this.trafficIndex] + (CONSTRUCTOR_WHITELIST[this.whitelistIndex] !== 'Без White-list' ? ' · ' + CONSTRUCTOR_WHITELIST[this.whitelistIndex] + ' WL' : '')).fontSize(10).fontColor(Color.White).opacity(0.48).margin({ top: 5 });
        }.width('100%').padding(16).backgroundColor(DirectTheme.panel).margin({ top: 18 });
        Row() { Text('РАСЧЁТ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text('—').fontSize(20).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').height(58).border({ width: { top: 1, bottom: 1 }, color: DirectTheme.line });
        Row() { Text('ПРОДОЛЖИТЬ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontColor(DirectTheme.acid); }.width('100%').height(52).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 12 }).onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.Payment); });
        Blank().height(28);
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private section(title: string) { Text(title).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 12, bottom: 8 }); }
  @Builder private chips(labels: string[], selected: number, onSelect: (index: number) => void) {
    Row() { ForEach(labels, (label: string, index: number) => { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(selected === index ? DirectTheme.acid : DirectTheme.ink).fontFamily('monospace').layoutWeight(1).height(38).textAlign(TextAlign.Center).backgroundColor(selected === index ? DirectTheme.ink : Color.Transparent).border({ width: 1, color: selected === index ? DirectTheme.ink : DirectTheme.line }).onClick(() => { onSelect(index); DirectHaptics.selection(); }); }); }.width('100%');
  }
}

const PERIOD_LABELS: string[] = ['7', '14', '30', '90', '180', '365'];
const NUMBER_LABELS: string[] = ['1', '3', '5', '10', '20'];
const TRAFFIC_LABELS: string[] = ['50 GB', '100 GB', '300 GB', '500 GB', '1 TB', '2 TB', 'Unlimited'];
const WHITELIST_LABELS: string[] = ['Без White-list', '20 GB', '50 GB', '100 GB', '250 GB', '500 GB'];