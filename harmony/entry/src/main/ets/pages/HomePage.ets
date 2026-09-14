import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics, DirectHapticEvent } from '../ui/Haptics';
import { DialView } from '../ui/DialView';
import { DirectIcon, DirectIconName } from '../ui/DirectIcons';

/**
 * Native ArkUI port of DirectHomePage + DialView.
 * Layout values, copy and state semantics intentionally follow the iOS DirectUI source.
 */
@Component
export struct HomePage {
  @Prop status: string = 'Disconnected';
  @Prop serverName: string = 'Авто';
  @Prop trafficToday: string = '0 B';
  @Prop runtime: string = '00:00:00';
  @Prop remaining: string = '—';
  /** iOS showsExternalSubscriptionControls — false for Direct-owned mode. */
  @Prop showsExternalSubscriptionControls: boolean = false;
  @Prop isRefreshingSubscription: boolean = false;
  @StorageProp('connection_mode') private connectionMode: string = 'Авто';
  onToggle: () => void = () => {};
  onServerTap: () => void = () => {};
  onReport: () => void = () => {};
  onProfiles: () => void = () => {};
  onRefreshSubscription: () => void = () => {};
  onChangeSubscription: () => void = () => {};
  onRemoveImported: () => void = () => {};

  private get connected(): boolean { return this.status === 'Connected'; }
  private get busy(): boolean { return this.status === 'Connecting' || this.status === 'Disconnecting'; }

  /** Short uppercase label for the РЕЖИМ row — iOS shows АВТО / … not DIRECT. */
  private modeShortLabel(): string {
    if (this.connectionMode === 'Авто' || this.connectionMode.length === 0) {
      return 'АВТО';
    }
    if (this.connectionMode === 'Пользовательский') {
      return 'РУЧНОЙ';
    }
    if (this.connectionMode === 'Максимальная скорость') {
      return 'СКОРОСТЬ';
    }
    if (this.connectionMode === 'Стабильный') {
      return 'СТАБ.';
    }
    if (this.connectionMode === 'Для видео') {
      return 'ВИДЕО';
    }
    if (this.connectionMode === '5G' || this.connectionMode === 'Антиблокировка') {
      return '5G';
    }
    return this.connectionMode.toUpperCase();
  }

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

  private statusColor(): string {
    if (this.connected) return DirectTheme.green;
    if (this.busy) return '#F29D38';
    return DirectTheme.danger;
  }

  private serverSubtitle(): string {
    if (this.serverName === 'Авто') {
      return this.connected ? 'Сейчас: определяем маршрут…' : 'Автовыбор маршрута';
    }
    return this.serverName;
  }

  build() {
    Column() {
      Text('DIRECT / VPN')
        .fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.muted).fontFamily('monospace')
        .width('100%')
        .padding({
          left: DirectTheme.pageHorizontal,
          right: DirectTheme.pageHorizontal,
          top: DirectTheme.pageTop,
          bottom: 7
        });

      Column({ space: 10 }) {
        Row() {
          Row().width(4).height(32).backgroundColor(this.statusColor());
          Column() {
            Text(this.statusTitle())
              .fontSize(DirectTypography.statusTitle)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(this.statusSubtitle()).fontSize(10).fontWeight(FontWeight.Medium)
              .fontColor(DirectTheme.muted).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 1 });
          }.alignItems(HorizontalAlign.Start).margin({ left: 10 }).layoutWeight(1);
          Column({ space: 2 }) {
            Text(this.connected ? 'ЗАЩИЩЕНО' : 'ОЖИДАНИЕ')
              .fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
              .fontColor(this.connected ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace');
            Row({ space: 3 }) {
              Text('ОТЧЁТ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
                .fontColor(DirectTheme.ink).fontFamily('monospace');
              DirectIcon({
                name: DirectIconName.ArrowUpRight,
                iconSize: 10,
                color: DirectTheme.ink,
                weight: 1.8
              });
            }
          }.alignItems(HorizontalAlign.End);
        }
          .width('100%')
          .onClick(() => {
            DirectHaptics.navigation();
            this.onReport();
          });

        Row({ space: 8 }) {
          Text('01').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.muted).fontFamily('monospace').width(18);
          Row().width(3).height(13).backgroundColor(DirectTheme.acid);
          Text('РЕЖИМ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.muted).fontFamily('monospace');
          Text(this.modeShortLabel()).fontSize(10).fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink).fontFamily('monospace');
          Blank();
          Text('ПРОФИЛЬ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.green).fontFamily('monospace');
          DirectIcon({
            name: DirectIconName.ChevronRight,
            iconSize: 10,
            color: DirectTheme.green,
            weight: 1.8
          });
        }.width('100%').height(30).padding({ left: 10, right: 10 })
          .border({ width: 1, color: DirectTheme.line })
          .onClick(() => {
            DirectHaptics.selection();
            this.onProfiles();
          });
      }.width('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal });

      Blank();

      DialView({
        isConnected: this.connected,
        isBusy: this.busy,
        onAction: () => this.onToggle()
      });

      Blank();

      Row({ space: 10 }) {
        Text('02').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.muted).fontFamily('monospace').width(20);
        // FlagImage substitute: ink square with code — 28×28 auto / 28×20 country
        Text(this.serverName === 'Авто' ? 'A' : 'DE')
          .fontSize(this.serverName === 'Авто' ? 12 : 8)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.acid)
          .fontFamily('monospace')
          .width(28)
          .height(this.serverName === 'Авто' ? 28 : 20)
          .textAlign(TextAlign.Center)
          .backgroundColor(DirectTheme.ink);
        Column({ space: 2 }) {
          Row({ space: 5 }) {
            Text(this.serverName === 'Авто' ? 'АВТО' : 'СЕРВЕР')
              .fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.green).fontFamily('monospace');
            Text('·').fontSize(DirectTypography.caption).fontColor(DirectTheme.muted)
              .fontFamily('monospace');
            Text('VPN DIRECT').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink).fontFamily('monospace');
          }
          Text(this.serverSubtitle())
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Circle().width(5).height(5).fill(this.serverName === 'Авто' ? DirectTheme.muted : DirectTheme.green);
            Text('— MS').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink).fontFamily('monospace');
          }
          DirectIcon({
            name: DirectIconName.ChevronRight,
            iconSize: 10,
            color: DirectTheme.muted,
            weight: 1.8
          });
        }.alignItems(HorizontalAlign.End);
      }.width('100%').height(DirectTheme.serverRowHeight)
        .padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal })
        .border({ width: { top: 1, bottom: 1 }, color: DirectTheme.line })
        .onClick(() => {
          DirectHaptics.play(DirectHapticEvent.ServerSelected);
          this.onServerTap();
        });

      if (this.showsExternalSubscriptionControls) {
        Row() {
          this.compactControl(DirectIconName.ArrowClockwise,
            this.isRefreshingSubscription ? '...' : 'ОБНОВИТЬ', false, false);
          Row().width(1).height(27).backgroundColor(DirectTheme.line);
          this.compactControl(DirectIconName.ArrowLeftArrowRight, 'ПОДПИСКА', false, false);
          Row().width(1).height(27).backgroundColor(DirectTheme.line);
          this.compactControl(DirectIconName.LocationNorth, 'СЕРВЕР', false, false);
          Row().width(1).height(27).backgroundColor(DirectTheme.line);
          this.compactControl(DirectIconName.Minus, 'УБРАТЬ', true, true);
        }
          .width('100%')
          .height(DirectTheme.controlHeight)
          .backgroundColor(DirectTheme.panelWash)
          .border({ width: 1, color: DirectTheme.line });
      }

      Row() {
        Column({ space: 2 }) {
          Text(this.trafficToday)
            .fontSize(DirectTypography.telemetry)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace');
          Text('СЕГОДНЯ')
            .fontSize(DirectTypography.telemetryLabel)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace');
        }.layoutWeight(1);
        Row().width(1).height(28).backgroundColor(DirectTheme.line);
        Column({ space: 2 }) {
          Text(this.connected ? this.runtime : '00:00:00')
            .fontSize(DirectTypography.telemetry)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace');
          Text('В СЕТИ')
            .fontSize(DirectTypography.telemetryLabel)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace');
        }.layoutWeight(1);
        Row().width(1).height(28).backgroundColor(DirectTheme.line);
        Column({ space: 2 }) {
          Text(this.remaining)
            .fontSize(DirectTypography.telemetry)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace');
          Text('ОСТАЛОСЬ')
            .fontSize(DirectTypography.telemetryLabel)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace');
        }.layoutWeight(1);
      }.width('100%').height(50).border({ width: { bottom: 1 }, color: DirectTheme.line });
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  compactControl(icon: string, title: string, destructive: boolean, disabled: boolean) {
    Row({ space: 5 }) {
      DirectIcon({
        name: icon,
        iconSize: 10,
        color: disabled
          ? '#597A8075'
          : (destructive ? DirectTheme.danger : DirectTheme.ink),
        weight: 1.4
      });
      Text(title)
        .fontSize(7.5)
        .fontWeight(FontWeight.Bold)
        .fontColor(disabled ? '#597A8075' : DirectTheme.muted)
        .fontFamily('monospace')
        .maxLines(1);
    }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .height('100%')
      .onClick(() => {
        if (disabled) {
          return;
        }
        DirectHaptics.selection();
        if (title === 'СЕРВЕР') {
          this.onServerTap();
        } else if (title === 'ПОДПИСКА') {
          this.onChangeSubscription();
        } else if (title === 'ОБНОВИТЬ' || title === '...') {
          this.onRefreshSubscription();
        } else if (title === 'УБРАТЬ') {
          this.onRemoveImported();
        }
      });
  }
}
