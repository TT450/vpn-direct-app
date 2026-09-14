import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectBackendRuntime } from '../backend/DirectBackendRuntime';

@Component
export struct DirectAuthParityV2 {
  @Prop flow: DirectFlow = DirectFlow.AuthLogin;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State email: string = '';
  @State password: string = '';
  @State name: string = '';
  @State code: string = '';
  @State confirmation: string = '';
  @State busy: boolean = false;
  @State message: string = '';

  private title(): string { if (this.flow === DirectFlow.AuthRegister) return 'Регистрация'; if (this.flow === DirectFlow.AuthRecovery) return 'Восстановление пароля'; if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) return 'Введите код'; if (this.flow === DirectFlow.AuthPhone) return 'Телефон'; if (this.flow === DirectFlow.AuthBot) return 'Аккаунт бота'; if (this.flow === DirectFlow.AuthSuccess) return 'Готово'; return this.flow === DirectFlow.AuthEmail ? 'Вход по email' : 'Вход'; }
  private subtitle(): string { if (this.flow === DirectFlow.AuthRecovery) return 'Отправим инструкции на email.'; if (this.flow === DirectFlow.AuthCode) return 'Код подтверждения для входа.'; if (this.flow === DirectFlow.AuthRegister) return 'Создайте аккаунт VPN Direct.'; return 'Безопасный вход и синхронизация состояния.'; }
  private async submit(): Promise<void> {
    if (this.busy) return;
    this.message = ''; this.busy = true;
    try {
      if (this.flow === DirectFlow.AuthLogin) { this.onFlow(DirectFlow.AuthEmail); return; }
      if (this.flow === DirectFlow.AuthSuccess) { this.onFlow(DirectFlow.Account); return; }
      if (this.flow === DirectFlow.AuthEmail) { const fn = DirectBackendRuntime.loginWithPassword; if (!fn) { this.message = 'Сервис входа недоступен'; return; } await fn(this.email.trim(), this.password); this.onFlow(DirectFlow.AuthSuccess); return; }
      if (this.flow === DirectFlow.AuthRegister) { const fn = DirectBackendRuntime.registerWithPassword; if (!fn) { this.message = 'Сервис регистрации недоступен'; return; } await fn(this.name.trim(), this.email.trim(), this.password, this.confirmation); this.onFlow(DirectFlow.AuthSuccess); return; }
      if (this.flow === DirectFlow.AuthRecovery) { const fn = DirectBackendRuntime.requestPasswordReset; if (!fn) { this.message = 'Восстановление недоступно'; return; } await fn(this.email.trim()); this.message = 'Если аккаунт существует, инструкции отправлены на email.'; return; }
      if (this.flow === DirectFlow.AuthCode) { if (this.code.trim().length === 0) { const send = DirectBackendRuntime.sendEmailCode; if (!send) { this.message = 'Отправка кода недоступна'; return; } await send(this.email.trim()); this.message = 'Код отправлен на email.'; return; } const verify = DirectBackendRuntime.verifyEmailCode; if (!verify) { this.message = 'Проверка кода недоступна'; return; } await verify(this.email.trim(), this.code.trim()); this.onFlow(DirectFlow.AuthSuccess); return; }
      this.message = 'Этот способ входа пока не подключён';
    } catch (err) { this.message = err instanceof Error ? err.message : `${err}`; } finally { this.busy = false; }
  }
  build() {
    Scroll() { Column() {
      Row() { Column() { Text(`ACCOUNT / ${this.flow === DirectFlow.AuthRegister ? 'NEW' : 'SIGN IN'}`).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(this.title()).fontSize(24).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 6 }); Text(this.subtitle()).fontSize(13).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('×').fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 16 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
      Column() { Row() { Text('DIRECT').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(52).height(42).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink); Column() { Text('БЕЗОПАСНЫЙ ВХОД').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('Продолжайте с выбранным способом').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).margin({ left: 12 }); }.width('100%').margin({ bottom: 18 });
        if (this.message.length > 0) Text(this.message).fontSize(11).fontColor(DirectTheme.danger).width('100%').padding(11).border({ width: 1, color: DirectTheme.line }).margin({ bottom: 12 });
        if (this.flow === DirectFlow.AuthEmail || this.flow === DirectFlow.AuthRegister || this.flow === DirectFlow.AuthRecovery || this.flow === DirectFlow.AuthCode) this.field('EMAIL', 'you@example.com', InputType.Email, this.email, (v: string) => this.email = v);
        if (this.flow === DirectFlow.AuthRegister) { this.field('ИМЯ', 'Как к вам обращаться', InputType.Normal, this.name, (v: string) => this.name = v); this.field('ПАРОЛЬ', 'Минимум 8 символов', InputType.Password, this.password, (v: string) => this.password = v); this.field('ПОВТОРИТЕ ПАРОЛЬ', 'Введите пароль ещё раз', InputType.Password, this.confirmation, (v: string) => this.confirmation = v); }
        else if (this.flow === DirectFlow.AuthEmail) this.field('ПАРОЛЬ', 'Введите пароль', InputType.Password, this.password, (v: string) => this.password = v);
        if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) this.field('КОД', '000000', InputType.Number, this.code, (v: string) => this.code = v);
        if (this.flow === DirectFlow.AuthPhone) this.field('ТЕЛЕФОН', '+994 …', InputType.PhoneNumber, this.email, (v: string) => this.email = v);
        if (this.flow === DirectFlow.AuthBot) this.field('КОД БОТА', 'Код из Telegram-бота', InputType.Normal, this.code, (v: string) => this.code = v);
        if (this.flow !== DirectFlow.AuthLogin && this.flow !== DirectFlow.AuthPhone && this.flow !== DirectFlow.AuthBot && this.flow !== DirectFlow.AuthSuccess) Row() { Text(this.busy ? '…' : this.actionTitle()).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontSize(12).fontColor(DirectTheme.acid); }.width('100%').height(52).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 4 }).onClick(() => { DirectHaptics.selection(); void this.submit(); });
        if (this.flow === DirectFlow.AuthLogin) { this.actionRow('ВОЙТИ ПО EMAIL', DirectFlow.AuthEmail); this.actionRow('ПРОДОЛЖИТЬ С APPLE', DirectFlow.AuthEmail); this.actionRow('ПРОДОЛЖИТЬ С GOOGLE', DirectFlow.AuthEmail); this.actionRow('ПО НОМЕРУ ТЕЛЕФОНА', DirectFlow.AuthPhone); this.actionRow('КОД ИЗ БОТА', DirectFlow.AuthBot); this.actionRow('СОЗДАТЬ АККАУНТ', DirectFlow.AuthRegister); this.actionRow('НЕ ПОЛУЧАЕТСЯ ВОЙТИ', DirectFlow.AuthRecovery); }
        if (this.flow === DirectFlow.AuthEmail) { this.link('Войти по одноразовому коду', DirectFlow.AuthCode); this.link('Создать аккаунт', DirectFlow.AuthRegister); this.link('Забыли пароль?', DirectFlow.AuthRecovery); }
        if (this.flow === DirectFlow.AuthSuccess) Row() { Text('ВХОД ВЫПОЛНЕН').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); Blank(); Text('✓').fontSize(14).fontColor(DirectTheme.green); }.width('100%').height(58).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => this.onFlow(DirectFlow.Account));
      }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 });
    }.width('100%').padding({ bottom: 24 }); }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  @Builder private field(label: string, placeholder: string, inputType: InputType, value: string, onChange: (v: string) => void) { Column() { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ bottom: 7 }); TextInput({ placeholder, text: value }).type(inputType).height(50).width('100%').fontSize(14).fontColor(DirectTheme.ink).backgroundColor(DirectTheme.fieldFill).border({ width: 1, color: DirectTheme.line }).padding({ left: 13, right: 13 }).margin({ bottom: 13 }).onChange((v: string) => onChange(v)); }.width('100%'); }
  @Builder private actionRow(title: string, flow: DirectFlow) { Row() { Text(title).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text('→').fontSize(11).fontColor(DirectTheme.muted); }.width('100%').height(52).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); if (title === 'ПРОДОЛЖИТЬ С APPLE' || title === 'ПРОДОЛЖИТЬ С GOOGLE') { this.message = 'Этот способ входа будет доступен после подключения соответствующего backend-провайдера.'; } else this.onFlow(flow); }); }
  @Builder private link(title: string, flow: DirectFlow) { Row() { Text(title).fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Blank(); Text('↗').fontSize(10).fontColor(DirectTheme.muted); }.width('100%').height(46).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); this.onFlow(flow); }); }
  private actionTitle(): string { if (this.flow === DirectFlow.AuthRegister) return 'СОЗДАТЬ АККАУНТ'; if (this.flow === DirectFlow.AuthRecovery) return 'ОТПРАВИТЬ ССЫЛКУ'; if (this.flow === DirectFlow.AuthCode) return this.code.trim().length === 0 ? 'ПОЛУЧИТЬ КОД' : 'ПОДТВЕРДИТЬ'; if (this.flow === DirectFlow.AuthPhone) return 'ПОЛУЧИТЬ КОД'; if (this.flow === DirectFlow.AuthPhoneCode) return 'ПОДТВЕРДИТЬ'; return 'ВОЙТИ'; }
}