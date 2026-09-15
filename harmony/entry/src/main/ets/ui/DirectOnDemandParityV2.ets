import { DirectTheme } from './Theme';
import { DirectIcon, DirectIconName } from './DirectIcons';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';

@Component
struct OnDemandHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  onClose: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text('СИСТЕМА / ON-DEMAND').fontSize(9).fontWeight(DirectTheme.weightBold).fontColor(DirectTheme.muted).fontFamily('monospace');
        Text(this.title).fontSize(24).fontWeight(DirectTheme.weightSemibold).fontColor(DirectTheme.ink).margin({ top: 6 });
        Text(this.subtitle).fontSize(11).fontWeight(DirectTheme.weightMedium).fontColor(DirectTheme.muted).margin({ top: 6 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Column() { DirectIcon({ name: DirectIconName.Xmark, iconSize: 12, color: DirectTheme.acid, weight: 1.8 }); }
        .width(36).height(36).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).backgroundColor(DirectTheme.ink)
        .onClick(() => { DirectHaptics.navigation(); this.onClose(); });
    }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 14 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }
}

@Component
export struct DirectOnDemandParityV2 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @StorageProp('pref_on_demand_mode') private mode: string = 'Отключено';
  @StorageProp('pref_on_demand_saved_mode') private savedMode: string = 'Отключено';
  private readonly modes: string[] = ['Отключено', 'Всегда', 'Неизвестный Wi‑Fi', 'Мобильная сеть'];

  private explanation(): string {
    if (this.mode === 'Всегда') return 'VPN будет автоматически подключаться при появлении любой сети.';
    if (this.mode === 'Неизвестный Wi‑Fi') return 'VPN включится в незнакомых Wi‑Fi сетях и останется выключенным в доверенных.';
    if (this.mode === 'Мобильная сеть') return 'VPN будет автоматически подключаться при переходе на мобильный интернет.';
    return 'VPN не будет подключаться автоматически.';
  }
  private choose(value: string): void {
    this.mode = value;
    this.savedMode = value;
    AppStorage.setOrCreate('pref_on_demand_mode', value);
    AppStorage.setOrCreate('pref_on_demand_saved_mode', value);
    DirectHaptics.selection();
  }
  @Builder private option(value: string) {
    Row() {
      Column() {
        Text(value).fontSize(14).fontWeight(DirectTheme.weightSemibold).fontColor(DirectTheme.ink);
        if (value === 'Всегда') Text('При любой доступной сети').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
        if (value === 'Неизвестный Wi‑Fi') Text('Только сети, которым ещё не доверяли').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
        if (value === 'Мобильная сеть') Text('При переходе на сотовые данные').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
        if (value === 'Отключено') Text('Ручное подключение').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      if (this.mode === value) DirectIcon({ name: DirectIconName.Checkmark, iconSize: 13, color: DirectTheme.green, weight: 1.6 });
    }.width('100%').constraintSize({ minHeight: 64 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => this.choose(value));
  }
  build() {
    Column() {
      OnDemandHeader({ title: 'Запуск по требованию', subtitle: 'Автоматическое включение VPN по типу сети', onClose: this.onClose });
      Scroll() {
        Column() {
          Column() {
            Row() {
              Column() {
                Text('ON-DEMAND').fontSize(9).fontWeight(DirectTheme.weightBold).fontColor('#6BFFFFFF').fontFamily('monospace');
                Text(this.mode).fontSize(22).fontWeight(DirectTheme.weightSemibold).fontColor(DirectTheme.white).margin({ top: 8 });
                Text(this.explanation()).fontSize(10).fontColor('#7AFFFFFF').margin({ top: 5 }).lineSpacing(3);
              }.alignItems(HorizontalAlign.Start).layoutWeight(1);
              DirectIcon({ name: DirectIconName.Connection, iconSize: 24, color: DirectTheme.acid, weight: 1.5 });
            }.width('100%').padding(16);
          }.width('100%').constraintSize({ minHeight: 118 }).backgroundColor(DirectTheme.panel).margin({ top: 24 });
          Row() {
            Text('01').fontSize(9).fontWeight(DirectTheme.weightBold).fontColor(DirectTheme.green).fontFamily('monospace');
            Text('РЕЖИМ').fontSize(9).fontWeight(DirectTheme.weightBold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ left: 11 });
            Blank();
            Text('ВЫБЕРИТЕ ОДИН').fontSize(9).fontWeight(DirectTheme.weightBold).fontColor(DirectTheme.muted).fontFamily('monospace');
          }.width('100%').height(40).border({ width: { top: 1 }, color: DirectTheme.ink }).margin({ top: 22 });
          this.option('Отключено');
          this.option('Всегда');
          this.option('Неизвестный Wi‑Fi');
          this.option('Мобильная сеть');
          Row({ space: 12 }) {
            DirectIcon({ name: DirectIconName.ArrowClockwise, iconSize: 13, color: DirectTheme.green, weight: 1.5 });
            Column() {
              Text('Сохранённый режим').fontSize(13).fontWeight(DirectTheme.weightSemibold).fontColor(DirectTheme.ink);
              Text(this.savedMode).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          }.width('100%').padding({ top: 15, bottom: 15 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
          Text('Настройка применяется к автоматическому запуску VPN. Ручное подключение с главного экрана продолжает работать независимо от выбранного режима.')
            .fontSize(10).fontColor(DirectTheme.muted).lineSpacing(3).padding({ top: 15 });
        }.width('100%').padding({ left: 20, right: 20, bottom: 28 });
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off);
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}
