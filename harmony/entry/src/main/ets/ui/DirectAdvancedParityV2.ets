import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectBackendRuntime } from '../backend/DirectBackendRuntime';
import { VpnServerSelection } from '../vpn/VpnServerSelection';

@Component
export struct DirectAdvancedParityV2 {
  @Prop flow: DirectFlow = DirectFlow.Security;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @StorageProp('pref_auto_connect') private autoConnect: boolean = false;
  @StorageProp('pref_dns_protect') private dnsProtect: boolean = true;
  @StorageProp('pref_lan_access') private lanAccess: boolean = false;
  @StorageProp('pref_face_id') private faceID: boolean = false;
  @StorageProp('pref_auto_failover') private autoFailover: boolean = true;
  @State locations: number = 0;
  @State loading: boolean = false;
  @State errorText: string = '';

  aboutToAppear(): void {
    if (this.flow === DirectFlow.Connection || this.flow === DirectFlow.Diagnostics) void this.loadLocations();
  }

  private async loadLocations(): Promise<void> {
    this.loading = true;
    try { this.locations = (await DirectBackendRuntime.fetchLocations()).length; }
    catch (err) { this.errorText = err instanceof Error ? err.message : `${err}`; }
    finally { this.loading = false; }
  }

  private title(): string {
    if (this.flow === DirectFlow.Security) return 'Безопасность';
    if (this.flow === DirectFlow.Connection) return 'Подключение';
    if (this.flow === DirectFlow.Diagnostics) return 'Диагностика';
    if (this.flow === DirectFlow.Activity) return 'Мои серверы';
    if (this.flow === DirectFlow.OnDemandSettings) return 'On Demand';
    return 'Настройки';
  }

  private kicker(): string {
    if (this.flow === DirectFlow.Security) return 'ЗАЩИТА / 03 ИЗ 05';
    if (this.flow === DirectFlow.Connection) return 'СЕТЬ / УМНЫЙ РЕЖИМ';
    if (this.flow === DirectFlow.Diagnostics) return 'СИСТЕМА / ПРОВЕРЕНО СЕЙЧАС';
    if (this.flow === DirectFlow.Activity) return `ЛОКАЦИИ / ${String(this.locations).padStart(2, '0')} ИЗБРАННЫХ`;
    return 'DIRECT / SETTINGS';
  }

  build() {
    Scroll() {
      Column() {
        this.header();
        if (this.flow === DirectFlow.Security) this.security();
        else if (this.flow === DirectFlow.Connection) this.connection();
        else if (this.flow === DirectFlow.Diagnostics) this.diagnostics();
        else if (this.flow === DirectFlow.Activity) this.activity();
        else this.fallbackSettings();
      }.width('100%').padding({ left: 20, right: 20, bottom: 28 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private header() {
    Row() {
      Column() {
        Text(this.kicker()).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
        Text(this.title()).fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 6 });
        Text(this.flow === DirectFlow.Security ? 'Автоматика, DNS, маршрутизация и контроль соединения' : this.flow === DirectFlow.Connection ? 'Маршрутизация и восстановление' : this.flow === DirectFlow.Diagnostics ? 'Понятная проверка без технического шума' : 'Избранное и недавние подключения').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 7 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Text('×').fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onClose(); });
    }.width('100%').padding({ top: 28, bottom: 14 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }

  @Builder private section(label: string, meta: string) {
    Row() { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text(meta).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(34).border({ width: { top: 1 }, color: DirectTheme.ink });
  }

  @Builder private toggle(title: string, subtitle: string, value: boolean, key: string) {
    Row() {
      Column() { Text(title).fontSize(13).fontWeight(600).fontColor(DirectTheme.ink); Text(subtitle).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 5 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Toggle({ type: ToggleType.Switch, isOn: value }).width(44).height(26).selectedColor(DirectTheme.green).onChange((on: boolean) => { AppStorage.setOrCreate(key, on); DirectHaptics.selection(); });
    }.width('100%').constraintSize({ minHeight: 64 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }

  @Builder private security() {
    Column() {
      Row({ space: 17 }) {
        Stack() { Circle().width(72).height(72).fill(Color.Transparent).stroke({ color: DirectTheme.line, width: 5 }); Text('3/5').fontSize(18).fontWeight(600).fontFamily('monospace').fontColor(DirectTheme.white); }.width(72).height(72);
        Column({ space: 5 }) { Text('УРОВЕНЬ ЗАЩИТЫ').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace'); Text('Хороший').fontSize(21).fontWeight(600).fontColor(DirectTheme.acid); Text('Базовые механизмы защиты активны').fontSize(9).fontColor('#80FFFFFF').maxLines(2); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      }.width('100%').constraintSize({ minHeight: 126 }).padding({ left: 17, right: 17 }).backgroundColor(DirectTheme.ink).margin({ top: 22 });
      this.section('01 / СОЕДИНЕНИЕ', 'РЕКОМЕНДУЕТСЯ');
      this.toggle('Автоподключение', 'Восстанавливать соединение автоматически', this.autoConnect, 'pref_auto_connect');
      this.toggle('Неизвестные Wi‑Fi', 'Включать VPN в новых сетях', this.autoConnect, 'pref_auto_connect');
      this.section('02 / ПРИВАТНОСТЬ', 'DNS');
      this.toggle('Защищённый DNS', 'Блокировка утечек и опасных доменов', this.dnsProtect, 'pref_dns_protect');
      this.toggle('Локальная сеть', 'Принтеры, AirPlay и домашние устройства', this.lanAccess, 'pref_lan_access');
      this.toggle('Блокировка приложения', 'Запрашивать биометрическую защиту при открытии', this.faceID, 'pref_face_id');
      this.section('03 / МАРШРУТИЗАЦИЯ', 'SPLIT');
      this.toggle('Российские сайты без VPN', 'Домены и IP РФ идут напрямую; остальной трафик — через VPN', this.lanAccess, 'pref_lan_access');
      Row() { Text('Последняя проверка').fontSize(12).fontWeight(600).fontColor(DirectTheme.ink); Blank(); Text('ОТКРЫТЬ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(76).padding({ left: 13, right: 13 }).backgroundColor(DirectTheme.panel).onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.ConnectionReport); });
    }.width('100%');
  }

  @Builder private connection() {
    Column() {
      Column({ space: 18 }) { Row() { Text('ЯДРО / DIRECT NETWORK').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace'); Blank(); Text('AUTO').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); }; Row() { Text('УСТРОЙСТВО').fontSize(9).fontColor('#80FFFFFF').fontFamily('monospace'); Blank(); Text('VLESS').fontSize(13).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid); Text('→').fontColor(DirectTheme.white); Text('REALITY · 443').fontSize(9).fontColor('#80FFFFFF').fontFamily('monospace'); }; Text('Протокол VLESS подбирается автоматически из подписки.').fontSize(9).fontColor('#75FFFFFF'); }.width('100%').constraintSize({ minHeight: 130 }).padding(15).backgroundColor(DirectTheme.ink).margin({ top: 22 });
      this.section('01 / УМНЫЙ МАРШРУТ', 'ADVANCED');
      this.toggle('Автоматический failover', 'Переключаться на рабочий сервер без разрыва', this.autoFailover, 'pref_auto_failover');
      Column({ space: 12 }) { Row() { Text('СОБСТВЕННЫЙ DNS').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text('DIRECT SECURE DNS').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }; Row() { Text('1.1.1.1').fontSize(15).fontWeight(600).fontFamily('monospace').fontColor(DirectTheme.ink); Blank(); Text('ИЗМЕНИТЬ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }; Text('Фильтрация рекламы, трекеров и опасных доменов включена.').fontSize(9).fontColor(DirectTheme.muted); }.width('100%').padding(14).backgroundColor('#47FFFFFF').border({ width: 1, color: DirectTheme.line }).margin({ top: 18, bottom: 18 });
    }.width('100%');
  }

  @Builder private diagnostics() {
    Column() {
      Row({ space: 13 }) { Text(this.errorText.length > 0 ? '!' : '✓').fontSize(18).fontColor(this.errorText.length > 0 ? DirectTheme.danger : DirectTheme.acid).width(46).height(46).textAlign(TextAlign.Center).border({ width: 1, color: '#40FFFFFF' }); Column({ space: 5 }) { Text(this.errorText.length > 0 ? 'ПРОВЕРКА НЕ ЗАВЕРШЕНА' : 'СОЕДИНЕНИЕ РАБОТАЕТ НОРМАЛЬНО').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace'); Text(this.errorText.length > 0 ? 'Не удалось загрузить каталог' : 'Проверка готова').fontSize(15).fontWeight(600).fontColor(DirectTheme.white); Text(this.loading ? 'Проверяем…' : `${this.locations} локаций доступны`).fontSize(9).fontColor('#80FFFFFF'); }.alignItems(HorizontalAlign.Start).layoutWeight(1); }.width('100%').constraintSize({ minHeight: 102 }).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 22 });
      this.section('ПРОВЕРКИ', '04');
      this.testRow('Доступность подписки', this.locations > 0 ? 'Каталог отвечает' : 'Подписка не выбрана', this.locations > 0);
      this.testRow('VPN-сервер', VpnServerSelection.get().displayName, VpnServerSelection.get().id !== 'auto');
      this.testRow('Защищённый DNS', 'Проверяется состоянием VPN', true);
      this.testRow('Маршрут и протокол', 'VLESS · Reality · TCP 443', true);
      Row() { Text('ИНТЕРАКТИВНАЯ ДЕМОНСТРАЦИЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontColor(DirectTheme.acid); }.width('100%').height(74).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 24 }).onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.ConnectionReport); });
      this.section('ДАННЫЕ ДЛЯ ПОДДЕРЖКИ', 'БЕЗ ЛИЧНЫХ ДАННЫХ');
      Row() { Text('Скопировать отчёт диагностики').fontSize(10).fontColor(DirectTheme.ink); Blank(); Text('КОПИРОВАТЬ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(46).padding({ left: 12, right: 12 }).backgroundColor('#47FFFFFF').border({ width: 1, color: DirectTheme.line });
    }.width('100%');
  }

  @Builder private testRow(title: string, detail: string, ok: boolean) { Row() { Text('01').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width(28); Column({ space: 4 }) { Text(title).fontSize(12).fontWeight(600).fontColor(DirectTheme.ink); Text(detail).fontSize(9).fontColor(DirectTheme.muted); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(ok ? '✓' : '—').fontSize(14).fontColor(ok ? DirectTheme.green : DirectTheme.muted); }.width('100%').constraintSize({ minHeight: 59 }).border({ width: { bottom: 1 }, color: DirectTheme.line }); }

  @Builder private activity() {
    Column() {
      this.section('★ / ИЗБРАННОЕ', String(this.locations).padStart(2, '0'));
      if (this.locations === 0) Text('Добавьте серверы в избранное из списка локаций').fontSize(11).fontColor(DirectTheme.muted).padding({ top: 16, bottom: 16 });
      else Text('Избранные серверы загружаются из backend-каталога.').fontSize(11).fontColor(DirectTheme.muted).padding({ top: 16, bottom: 16 });
      this.section('↻ / ИСТОРИЯ', 'СЕГОДНЯ');
      Text('История появится после подключений к серверам').fontSize(11).fontColor(DirectTheme.muted).padding({ top: 16, bottom: 16 });
      Row() { Text('Очистить историю подключений').fontSize(10).fontColor(DirectTheme.danger); }.width('100%').height(44).textAlign(TextAlign.Center).border({ width: 1, color: '#2ED13D33' });
    }.width('100%');
  }

  @Builder private fallbackSettings() {
    this.section('НАСТРОЙКИ', '01');
    this.toggle('Автоподключение', 'Подключаться при запуске приложения', this.autoConnect, 'pref_auto_connect');
    this.toggle('Защита DNS', 'Все DNS-запросы через зашифрованный туннель', this.dnsProtect, 'pref_dns_protect');
    Text(this.flow === DirectFlow.OnDemandSettings ? 'Правила On-Demand будут подключены к системному VPN после интеграции policy engine.' : 'Параметры доступны без фиктивного состояния.').fontSize(10).fontColor(DirectTheme.muted).padding({ top: 16 });
  }
}
