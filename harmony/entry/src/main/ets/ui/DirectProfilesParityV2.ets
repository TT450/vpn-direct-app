import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectIcon, DirectIconName } from './DirectIcons';

interface ConnectionProfile { mark: string; title: string; detail: string; }
@Component
export struct DirectProfilesParityV2 {
  onClose: () => void = () => {};
  @StorageProp('connection_mode') private mode: string = 'Авто';
  private readonly profiles: ConnectionProfile[] = [
    { mark: 'A', title: 'Авто', detail: 'Баланс скорости и стабильности' },
    { mark: 'M', title: 'Пользовательский', detail: 'Только выбранный вручную сервер' },
    { mark: 'S', title: 'Максимальная скорость', detail: 'Ближайший сервер с минимальным ping' },
    { mark: 'R', title: 'Стабильный', detail: 'Надёжный маршрут и failover' },
    { mark: 'V', title: 'Для видео', detail: 'Высокая пропускная способность' },
    { mark: 'X', title: '5G', detail: 'Оптимизация для мобильных сетей' }
  ];
  private selected(title: string): boolean { return title === '5G' ? this.mode === '5G' || this.mode === 'Антиблокировка' : this.mode === title; }
  private select(title: string): void { AppStorage.setOrCreate('connection_mode', title); DirectHaptics.selection(); this.onClose(); }
  build() {
    Column() {
      Row() {
        Column() { Text(`РЕЖИМ / ${String(this.profiles.length).padStart(2, '0')}`).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Режим подключения').fontSize(24).fontWeight(DirectTheme.weightSemibold).fontColor(DirectTheme.ink).margin({ top: 6 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Column() { DirectIcon({ name: DirectIconName.Xmark, iconSize: 12, color: DirectTheme.acid, weight: 1.8 }); }.width(36).height(36).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onClose(); });
      }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 14 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
      Scroll() {
        Column() {
          Text('Выберите, как клиент подбирает сервер и ведёт себя при сбое.').fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.muted).padding({ top: 12, bottom: 10 });
          Column() { ForEach(this.profiles, (profile: ConnectionProfile, index: number) => this.profileRow(profile, index), (profile: ConnectionProfile) => profile.title); }.width('100%').border({ width: 1, color: DirectTheme.line });
          Blank().height(28);
        }.width('100%').padding({ left: 20, right: 20, bottom: 28 });
      }.layoutWeight(1).scrollBar(BarState.Off);
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  @Builder private profileRow(profile: ConnectionProfile, index: number) {
    Row({ space: 10 }) {
      Text(String(index + 1).padStart(2, '0')).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width(18);
      Text(profile.mark).fontSize(12).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(28).height(28).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink);
      Column({ space: 2 }) { Text(profile.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).maxLines(1); Text(profile.detail).fontSize(10).fontWeight(FontWeight.Medium).fontColor(DirectTheme.muted).maxLines(1); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      DirectIcon({ name: this.selected(profile.title) ? DirectIconName.Checkmark : DirectIconName.ChevronRight, iconSize: 10, color: this.selected(profile.title) ? DirectTheme.green : DirectTheme.muted, weight: 1.7 });
    }.width('100%').constraintSize({ minHeight: 56 }).padding({ left: 10, right: 10 }).backgroundColor(this.selected(profile.title) ? DirectTheme.acidSelected : Color.Transparent).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => this.select(profile.title));
  }
}
