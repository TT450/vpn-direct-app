import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics, DirectHapticEvent } from '../ui/Haptics';

@Component
export struct HomePage {
  @Prop status: string = 'Disconnected';
  @Prop serverName: string = 'Авто';
  @Prop onToggle: () => void = () => {};
  @Prop onServerTap: () => void = () => {};

  private get connected(): boolean { return this.status === 'Connected'; }
  private get busy(): boolean { return this.status === 'Connecting' || this.status === 'Disconnecting'; }
  private statusTitle(): string {
    if (this.status === 'Connecting') return 'ПОДКЛЮЧЕНИЕ';
    if (this.status === 'Disconnecting') return 'ОТКЛЮЧЕНИЕ';
    if (this.status === 'Connected') return 'VPN подключён';
    if (this.status.indexOf('failed') >= 0) return 'Ошибка подключения';
    return 'VPN отключён';
  }
  private statusSubtitle(): string {
    if (this.status === 'Connecting') return 'Устанавливаем защищённое соединение';
    if (this.status === 'Disconnecting') return 'Завершаем VPN-сессию';
    if (this.status === 'Connected') return 'Защищённое соединение активно';
    if (this.status.indexOf('failed') >= 0) return 'Нажмите на отчёт для подробностей';
    return 'Соединение не установлено';
  }

  build() {
    Column() {
      Text('DIRECT / VPN').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted)
        .fontFamily('monospace').width('100%').padding({ top: DirectTheme.pageTop, bottom: 7 });

      Column() {
        Row() {
          Rectangle().width(4).height(32).fill(this.connected ? DirectTheme.green : (this.busy ? '#F29D38' : DirectTheme.danger));
          Column() {
            Text(this.statusTitle()).fontSize(DirectTypography.statusTitle).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(this.statusSubtitle()).fontSize(10).fontWeight(FontWeight.Medium).fontColor(DirectTheme.muted)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
          }.alignItems(HorizontalAlign.Start).margin({ left: 10 });
          Blank();
          Column() {
            Text(this.connected ? 'ЗАЩИЩЕНО' : 'ОЖИДАНИЕ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
              .fontColor(this.connected ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace');
            Row() { Text('ОТЧЁТ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
              Text('↗').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).margin({ left: 3 }); }
          }.alignItems(HorizontalAlign.End);
        }.width('100%');

        Row() {
          Text('01').fontSize(DirectTypography.caption).fontColor(DirectTheme.muted).fontFamily('monospace').width(18);
          Rectangle().width(3).height(13).fill(DirectTheme.acid).margin({ right: 8 });
          Text('РЕЖИМ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Text('DIRECT').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ left: 7 });
          Blank(); Text('ПРОФИЛЬ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
          Text('›').fontSize(12).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).margin({ left: 3 });
        }.width('100%').height(30).padding({ left: 10, right: 10 }).border({ width: 1, color: DirectTheme.line });
      }.width('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal });

      Blank();
      Stack() {
        Circle().width(264).height(264).fill(DirectTheme.paper).stroke(this.connected ? DirectTheme.ink : DirectTheme.line, 2);
        Circle().width(180).height(180).fill(DirectTheme.ink).stroke('#4777F7', 0.5)
          .shadow({ radius: 18, color: '#33000000', offsetX: 0, offsetY: 9 });
        Column() {
          Text('A / 01').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor('#7AFFFFFF').fontFamily('monospace');
          Text(this.busy ? '•••' : (this.connected ? 'ON' : 'OFF')).fontSize(DirectTypography.display).fontWeight(FontWeight.Medium)
            .fontColor(this.connected ? DirectTheme.acid : '#D1D1D1').margin({ top: 5, bottom: 5 });
          if (this.connected) Text('Нажмите, чтобы отключить').fontSize(DirectTypography.caption).fontColor('#80FFFFFF');
          else { Column() { Text('Нажмите, чтобы').fontSize(DirectTypography.caption).fontColor('#80FFFFFF'); Text('подключить').fontSize(DirectTypography.caption).fontColor('#80FFFFFF'); } }
        }
        Capsule().width(3).height(26).fill(this.connected ? DirectTheme.acid : '#8CFFFFFF').offset({ x: 0, y: -78 })
          .rotate({ x: 0, y: 0, z: this.connected ? 132 : -132 });
      }.width(264).height(290).onClick(() => {
        DirectHaptics.play(this.connected ? DirectHapticEvent.ToggleOff : DirectHapticEvent.ToggleOn);
        this.onToggle();
      });

      Blank();
      Row() {
        Text('02').fontSize(DirectTypography.caption).fontColor(DirectTheme.muted).fontFamily('monospace').width(20);
        Text(this.serverName === 'Авто' ? 'A' : 'DE').fontSize(this.serverName === 'Авто' ? 12 : 8).fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.acid).fontFamily('monospace').width(28).height(this.serverName === 'Авто' ? 28 : 20)
          .textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink);
        Column() {
          Row() { Text(this.serverName === 'Авто' ? 'АВТО' : 'СЕРВЕР').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
            Text('·').fontSize(DirectTypography.caption).fontColor(DirectTheme.muted).margin({ left: 4, right: 4 });
            Text('VPN DIRECT').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); }
          Text(this.serverName === 'Авто' ? 'Автовыбор маршрута' : this.serverName).fontSize(14).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 2 });
        }.alignItems(HorizontalAlign.Start).margin({ left: 10 });
        Blank();
        Column() { Row() { Circle().width(5).height(5).fill(DirectTheme.green).margin({ right: 4 }); Text('— MS').fontSize(DirectTypography.caption).fontColor(DirectTheme.ink).fontFamily('monospace'); }
          Text('›').fontSize(12).fontColor(DirectTheme.muted); }.alignItems(HorizontalAlign.End);
      }.width('100%').height(58).padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal })
        .border({ width: { top: 1, bottom: 1 }, color: DirectTheme.line }).onClick(() => {
          DirectHaptics.play(DirectHapticEvent.ServerSelected); this.onServerTap();
        });

      Row() {
        Column() { Text('0 B').fontSize(DirectTypography.telemetry).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('СЕГОДНЯ').fontSize(DirectTypography.telemetryLabel).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); }.layoutWeight(1);
        Rectangle().width(1).height(28).fill(DirectTheme.line);
        Column() { Text('00:00:00').fontSize(DirectTypography.telemetry).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('В СЕТИ').fontSize(DirectTypography.telemetryLabel).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); }.layoutWeight(1);
        Rectangle().width(1).height(28).fill(DirectTheme.line);
        Column() { Text('—').fontSize(DirectTypography.telemetry).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('ОСТАЛОСЬ').fontSize(DirectTypography.telemetryLabel).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); }.layoutWeight(1);
      }.width('100%').height(50).border({ width: { bottom: 1 }, color: DirectTheme.line });
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}
