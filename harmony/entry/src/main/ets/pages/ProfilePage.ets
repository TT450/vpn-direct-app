import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics } from '../ui/Haptics';
import { DirectIcon, DirectIconName } from '../ui/DirectIcons';
import { DirectFlow } from '../ui/DirectFlows';
import { SESSION_HAS_SUBSCRIPTION, SESSION_DISPLAY_NAME, SESSION_REMAINING_DAYS, SESSION_BALANCE_CENTS, SESSION_PLAN_NAME } from '../model/DirectSessionStore';
import { DirectBackendRuntime } from '../backend/DirectBackendRuntime';
interface SettingsRowData { title: string; detail: string; flow: DirectFlow; icon: DirectIconName; }
interface LegalRowData { title: string; subtitle: string; flow: DirectFlow; }
@Component
export struct ProfilePage {
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @StorageProp(SESSION_HAS_SUBSCRIPTION) private hasSubscription: boolean = false;
  @StorageProp(SESSION_DISPLAY_NAME) private displayName: string = '';
  @StorageProp(SESSION_REMAINING_DAYS) private remainingDays: number = 0;
  @StorageProp(SESSION_BALANCE_CENTS) private balanceCents: number = 0;
  @StorageProp(SESSION_PLAN_NAME) private planName: string = '';
  @StorageProp('vpn_status') private vpnStatus: string = 'Disconnected';
  @StorageProp('vpn_connected_at') private connectedAt: number = 0;
  @State private deviceCount: number = 0;
  @State private deleteBusy: boolean = false;
  @State private deleteMessage: string = '';
  private readonly settingsRows: SettingsRowData[] = [
    { title: 'Безопасность', detail: 'Автоподключение, DNS и российские сайты', flow: DirectFlow.Security, icon: DirectIconName.Shield },
    { title: 'Подключение', detail: 'Протокол, failover и антиблокировка', flow: DirectFlow.Connection, icon: DirectIconName.Connection },
    { title: 'Диагностика', detail: 'Проверка и автоматическое исправление', flow: DirectFlow.Diagnostics, icon: DirectIconName.Waveform },
    { title: 'Мои серверы', detail: 'Избранное и история подключений', flow: DirectFlow.Activity, icon: DirectIconName.Star },
    { title: 'Системные настройки', detail: 'Ядро, туннель и служебные параметры', flow: DirectFlow.SystemSettings, icon: DirectIconName.SlidersHorizontal }
  ];
  private readonly legalRows: LegalRowData[] = [
    { title: 'Политика конфиденциальности', subtitle: 'Какие данные обрабатываются, зачем и как удаляются', flow: DirectFlow.Privacy },
    { title: 'Условия использования', subtitle: 'Правила использования приложения и сервиса', flow: DirectFlow.Legal },
    { title: 'EULA', subtitle: 'Стандартное лицензионное соглашение App Store', flow: DirectFlow.Legal },
    { title: 'VPN и обработка данных', subtitle: 'Обработка данных VPN‑соединения и ограничения их использования', flow: DirectFlow.Privacy },
    { title: 'Тарифы и условия сервиса', subtitle: 'Стоимость и условия предоставления VPN‑ресурса', flow: DirectFlow.Legal },
    { title: 'Возврат App Store', subtitle: 'Запрос возврата платежа, проведённого через Apple', flow: DirectFlow.Legal },
    { title: 'Лицензия открытого кода', subtitle: 'Лицензионные условия исходного кода приложения', flow: DirectFlow.Legal },
    { title: 'Уведомления о компонентах', subtitle: 'Third‑party notices и сведения о сторонних компонентах', flow: DirectFlow.Legal }
  ];
  aboutToAppear(): void { void this.loadDeviceCount(); }
  private async loadDeviceCount(): Promise<void> { try { this.deviceCount = (await DirectBackendRuntime.fetchAccountDevices()).length; } catch { this.deviceCount = 0; } }
  private protectedTime(): string { if (this.vpnStatus !== 'Connected' || this.connectedAt <= 0) return '00:00'; const seconds = Math.max(0, Math.floor((Date.now() - this.connectedAt) / 1000)); const h = Math.floor(seconds / 3600); const m = Math.floor((seconds % 3600) / 60); return h > 0 ? `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}` : `${String(m).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`; }
  private balanceLabel(): string { return `$${(Math.max(0, this.balanceCents) / 100).toFixed(2)}`; }
  private planDeviceLimit(): number { const p = this.planName.toLowerCase(); if (p.includes('ultra')) return 20; if (p.includes('max')) return 10; if (p.includes('pro')) return 5; if (p.includes('plus')) return 3; return 1; }
  private accountInitial(): string { return this.displayName.length > 0 ? 'D' : 'A'; }
  private async deleteAccount(): Promise<void> { if (this.deleteBusy) return; this.deleteBusy = true; this.deleteMessage = ''; try { const fn = DirectBackendRuntime.deleteAccount; if (fn === null) { this.deleteMessage = 'Удаление аккаунта пока недоступно.'; return; } await fn(); if (DirectBackendRuntime.logout !== null) await DirectBackendRuntime.logout(); this.deleteMessage = 'Аккаунт удалён.'; DirectHaptics.play('authSuccess'); } catch (err) { this.deleteMessage = err instanceof Error ? err.message : `${err}`; DirectHaptics.play('error'); } finally { this.deleteBusy = false; } }
  build() {
    Scroll() {
      Column() {
        Text('АККАУНТ / ALD–0248').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
        Text('Профиль').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).width('100%').margin({ top: 7 });
        Text('Управление приложением и безопасностью').fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ top: 4 });
        Row() { Text(this.accountInitial()).fontSize(30).fontWeight(FontWeight.Medium).fontColor(DirectTheme.acid).fontFamily('monospace').width(62).height(62).textAlign(TextAlign.Center).border({ width: 1, color: '#40FFFFFF' }); Column() { Text('DIRECT ACCOUNT').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor('#73FFFFFF').fontFamily('monospace'); Text(this.displayName.length > 0 ? this.displayName : 'Войти в Direct').fontSize(19).fontWeight(600).fontColor(DirectTheme.white).maxLines(1).margin({ top: 5 }); Text(this.displayName.length > 0 ? 'Аккаунт Direct · только этот аккаунт' : 'Оплата и вход').fontSize(10).fontColor('#80FFFFFF').maxLines(1).margin({ top: 5 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 16 }); DirectIcon({ name: DirectIconName.ArrowUpRight, iconSize: 14, color: DirectTheme.acid, weight: 1.6 }); }.width('100%').height(116).padding({ left: 16, right: 16 }).backgroundColor(DirectTheme.ink).margin({ top: 28 }).onClick(() => { DirectHaptics.selection(); this.onFlow(this.displayName.length > 0 ? DirectFlow.Account : DirectFlow.AuthLogin); });
        Row({ space: 0 }) { this.profileStat('ПОДПИСОК', this.hasSubscription ? '01' : '00'); this.profileStat('УСТРОЙСТВ', String(this.planDeviceLimit()).padStart(2, '0')); this.profileStat('ЗАЩИЩЕНО', this.protectedTime()); }.width('100%').height(76).border({ width: { bottom: 1 }, color: DirectTheme.line });
        this.sectionHeader('01', 'АККАУНТ');
        this.utilityRow('BAL', 'Баланс', this.balanceLabel(), true, DirectFlow.Balance); this.utilityRow('DEV', 'Устройства', 'Активные сеансы и лимит тарифа', false, DirectFlow.Devices); this.utilityRow('PAY', 'Платежи', 'История оплат и возвратов', false, DirectFlow.PaymentHistory); this.utilityRow('PROMO', 'Промокод', 'Активировать код от VPN Direct', true, DirectFlow.Promo); this.utilityRow('HELP', 'Поддержка', 'Оплата, вход, подписка и подключение', false, DirectFlow.Support); this.utilityRow('LINK', 'Способы входа', 'Apple, email и бот — безопасная склейка', false, DirectFlow.AccountLinking);
        this.sectionHeader('02', 'НАСТРОЙКИ'); Column() { ForEach(this.settingsRows, (row: SettingsRowData, index: number) => this.settingsRow(row, index + 1)); }.width('100%').margin({ top: 5 });
        this.sectionHeader('03', 'ЮРИДИЧЕСКАЯ ИНФОРМАЦИЯ'); Column() { ForEach(this.legalRows, (row: LegalRowData) => this.legalRow(row)); }.width('100%').margin({ top: 5 });
        this.aboutBlock(); this.rateRow(); this.deleteRow(); if (this.deleteMessage.length > 0) Text(this.deleteMessage).fontSize(10).fontColor(DirectTheme.danger).width('100%').padding({ top: 10 }); Blank().height(28);
      }.width('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 24 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  @Builder profileStat(label: string, value: string) { Column({ space: 7 }) { Text(label).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(value).fontSize(16).fontWeight(600).fontColor(DirectTheme.ink).fontFamily('monospace').maxLines(1); }.layoutWeight(1).height('100%').alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center).padding({ left: 12 }).border({ width: { left: 1 }, color: DirectTheme.line }); }
  @Builder sectionHeader(number: string, title: string) { Row() { Text(number).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text(title).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ left: 8 }); Blank(); }.width('100%').height(36).margin({ top: 18 }).border({ width: { top: 1 }, color: DirectTheme.ink }); }
  @Builder utilityRow(mark: string, title: string, detail: string, accent: boolean, flow: DirectFlow) { Row({ space: 12 }) { Text(mark).fontSize(8).fontWeight(FontWeight.Bold).fontColor(accent ? DirectTheme.acid : DirectTheme.ink).fontFamily('monospace').width(42).height(42).textAlign(TextAlign.Center).backgroundColor(accent ? DirectTheme.ink : '#61FFFFFF').border({ width: accent ? 0 : 1, color: DirectTheme.line }); Column() { Text(title).fontSize(13).fontWeight(600).fontColor(DirectTheme.ink); Text(detail).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); DirectIcon({ name: DirectIconName.ArrowUpRight, iconSize: 11, color: DirectTheme.ink, weight: 1.5 }); }.width('100%').constraintSize({ minHeight: 64 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); this.onFlow(flow); }); }
  @Builder settingsRow(row: SettingsRowData, index: number) { Row({ space: 13 }) { Text(String(index).padStart(2, '0')).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width(21); DirectIcon({ name: row.icon, iconSize: 23, color: DirectTheme.ink, weight: 1.5 }); Column() { Text(row.title).fontSize(14).fontWeight(600).fontColor(DirectTheme.ink).maxLines(1); Text(row.detail).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }).maxLines(2); }.alignItems(HorizontalAlign.Start).layoutWeight(1); DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 11, color: DirectTheme.ink, weight: 1.5 }); }.width('100%').height(67).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); this.onFlow(row.flow); }); }
  @Builder legalRow(row: LegalRowData) { Row({ space: 13 }) { DirectIcon({ name: DirectIconName.Document, iconSize: 14, color: DirectTheme.ink, weight: 1.5 }); Column() { Text(row.title).fontSize(14).fontWeight(600).fontColor(DirectTheme.ink); Text(row.subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }).maxLines(2); }.alignItems(HorizontalAlign.Start).layoutWeight(1); DirectIcon({ name: DirectIconName.ArrowUpRight, iconSize: 10, color: DirectTheme.muted, weight: 1.5 }); }.width('100%').constraintSize({ minHeight: 67 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); this.onFlow(row.flow); }); }
  @Builder aboutBlock() { Column() { Row() { Text('О ПРИЛОЖЕНИИ').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); }.width('100%').height(36).margin({ top: 18 }).border({ width: { top: 1 }, color: DirectTheme.ink }); Column() { this.aboutRow('НАЗВАНИЕ', 'VPN Direct'); this.aboutRow('ВЕРСИЯ', 'HarmonyOS'); this.aboutRow('ЯДРО', 'sing-box'); this.aboutRow('VPN ENGINE', 'VPN Connection'); }.width('100%').padding({ left: 15, right: 15, top: 4, bottom: 4 }).backgroundColor(DirectTheme.panel); }.width('100%'); }
  @Builder aboutRow(label: string, value: string) { Row({ space: 12 }) { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace').width(84); Text(value).fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.white).fontFamily('monospace').layoutWeight(1); }.width('100%').constraintSize({ minHeight: 44 }).border({ width: { bottom: 1 }, color: '#1AFFFFFF' }); }
  @Builder rateRow() { Row({ space: 13 }) { DirectIcon({ name: DirectIconName.Star, iconSize: 14, color: DirectTheme.dialBlue, weight: 1.5 }); Column() { Text('Оценить в App Store').fontSize(14).fontWeight(600).fontColor(DirectTheme.ink); Text('Открыть страницу VPN Direct в App Store').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); DirectIcon({ name: DirectIconName.ArrowUpRight, iconSize: 10, color: DirectTheme.muted, weight: 1.5 }); }.width('100%').constraintSize({ minHeight: 64 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).margin({ top: 5 }).onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.About); }); }
  @Builder deleteRow() { Row({ space: 13 }) { DirectIcon({ name: DirectIconName.Trash, iconSize: 14, color: DirectTheme.danger, weight: 1.5 }); Column() { Text('Удалить аккаунт').fontSize(14).fontWeight(600).fontColor(DirectTheme.danger); Text('Безвозвратно удалить данные аккаунта с сервера').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); if (this.deleteBusy) Text('…').fontSize(11).fontColor(DirectTheme.danger); else DirectIcon({ name: DirectIconName.Trash, iconSize: 11, color: DirectTheme.danger, weight: 1.5 }); }.width('100%').constraintSize({ minHeight: 67 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).margin({ top: 18 }).onClick(() => { void this.deleteAccount(); }); }
}
