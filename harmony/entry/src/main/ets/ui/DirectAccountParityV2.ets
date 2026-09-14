import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectIcon, DirectIconName } from './DirectIcons';
import { DirectBackendRuntime } from '../backend/DirectBackendRuntime';
import { SESSION_AUTHENTICATED, SESSION_AUTH_METHOD, SESSION_ACCOUNT_KIND, SESSION_DISPLAY_NAME, SESSION_SUBSCRIPTION_URL } from '../model/DirectSessionStore';

@Component
export struct DirectAccountParityV2 {
  onClose: () => void = () => {}; onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @StorageProp(SESSION_AUTHENTICATED) private authenticated: boolean = false; @StorageProp(SESSION_AUTH_METHOD) private authMethod: string = ''; @StorageProp(SESSION_ACCOUNT_KIND) private accountKind: string = ''; @StorageProp(SESSION_DISPLAY_NAME) private displayName: string = ''; @StorageProp(SESSION_SUBSCRIPTION_URL) private subscriptionUrl: string = '';
  @State private busy: boolean = false; @State private message: string = '';
  private async refreshAccount(): Promise<void> { const fn = DirectBackendRuntime.refreshAccount; if (fn === null) { this.message = 'Сервис аккаунта недоступен'; return; } this.busy = true; try { await fn(); this.message = 'Обновлено'; } catch (err) { this.message = err instanceof Error ? err.message : `${err}`; } finally { this.busy = false; } }
  private async logout(): Promise<void> { const fn = DirectBackendRuntime.logout; if (fn === null) { this.message = 'Выход недоступен'; return; } this.busy = true; try { await fn(); this.message = ''; } catch (err) { this.message = err instanceof Error ? err.message : `${err}`; } finally { this.busy = false; } }
  private accountTitle(): string { return this.displayName.length > 0 ? this.displayName : 'Аккаунт'; }
  private accountKindText(): string { return this.accountKind === 'telegram' ? 'Аккаунт Telegram' : 'Аккаунт приложения'; }
  build() { Scroll() { Column() {
    Column() { Text('VPN DIRECT').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(this.authenticated ? 'Аккаунт' : 'Вход').fontSize(22).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 7 }); Text(this.authenticated ? 'Сессия только этого аккаунта — другие способы входа независимы' : 'Нужен для оплаты. Способы входа не объединяются').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 4 }); }.width('100%').padding({ top: DirectTheme.pageTop });
    if (this.authenticated) {
      Column() { Text(`СЕССИЯ · ${(this.authMethod.length > 0 ? this.authMethod : 'ACCOUNT').toUpperCase()}`).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Text(this.accountTitle()).fontSize(16).fontWeight(600).fontColor(DirectTheme.white).margin({ top: 8 }); Text(this.accountKindText()).fontSize(11).fontColor('#8CFFFFFF').margin({ top: 5 }); if (this.subscriptionUrl.length > 0) Text(this.subscriptionUrl).fontSize(10).fontColor('#80FFFFFF').fontFamily('monospace').maxLines(2).margin({ top: 5 }); }.width('100%').padding(16).backgroundColor(DirectTheme.panel).margin({ top: 22 });
      this.row('Обновить аккаунт', 'Синхронизация подписки этого аккаунта', DirectFlow.Account, true); this.row('Код из бота', 'Вход в аккаунт @vpndirectbot', DirectFlow.AuthBot, false); this.row('По номеру телефона', 'Отдельный app-аккаунт', DirectFlow.AuthPhone, false); this.row('Другой способ входа', 'Email, Apple, Google — тоже отдельные аккаунты', DirectFlow.AuthLogin, false);
      Row() { Column() { Text('Выйти').fontSize(13).fontWeight(600).fontColor(DirectTheme.ink); Text('Завершить сессию').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 11, color: DirectTheme.muted, weight: 1.5 }); }.width('100%').padding({ top: 16, bottom: 16 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); void this.logout(); });
    } else {
      Text('Email, Apple, Google, телефон и код из бота — независимые аккаунты. Просмотр тарифов и импорт внешних подписок доступны без регистрации.').fontSize(11).fontColor(DirectTheme.muted).margin({ top: 22 });
      Text('Войти').fontSize(13).fontWeight(FontWeight.Bold).fontColor(DirectTheme.white).width('100%').height(52).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink).margin({ top: 20 }).onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.AuthLogin); });
      Text('Регистрация').fontSize(13).fontWeight(600).fontColor(DirectTheme.ink).width('100%').height(48).textAlign(TextAlign.Center).border({ width: 1, color: DirectTheme.line }).margin({ top: 8 }).onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.AuthRegister); });
    }
    if (this.message.length > 0) Text(this.message).fontSize(11).fontColor(DirectTheme.muted).margin({ top: 12 });
  }.padding({ left: 20, right: 20, bottom: 34 }).opacity(this.busy ? 0.58 : 1); }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper); }
  @Builder private row(title: string, subtitle: string, flow: DirectFlow, refresh: boolean) { Row() { Column() { Text(title).fontSize(13).fontWeight(600).fontColor(DirectTheme.ink); Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); DirectIcon({ name: DirectIconName.ChevronRight, iconSize: 11, color: DirectTheme.muted, weight: 1.5 }); }.width('100%').padding({ top: 16, bottom: 16 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); if (refresh) void this.refreshAccount(); else this.onFlow(flow); }); }
}
