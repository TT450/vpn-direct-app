import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectBackendRuntime } from '../backend/DirectBackendRuntime';

@Component
export struct DirectAuthParityV3 {
  @Prop flow: DirectFlow = DirectFlow.AuthLogin;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State email: string = '';
  @State password: string = '';
  @State name: string = '';
  @State confirmation: string = '';
  @State code: string = '';
  @State revealed: boolean = false;
  @State confirmationRevealed: boolean = false;
  @State busy: boolean = false;
  @State sent: boolean = false;
  @State message: string = '';

  private title(): string { if (this.flow === DirectFlow.AuthEmail) return 'Вход по email'; if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) return 'Введите код'; if (this.flow === DirectFlow.AuthRegister) return 'Регистрация'; if (this.flow === DirectFlow.AuthRecovery) return 'Восстановление пароля'; if (this.flow === DirectFlow.AuthPhone) return 'Телефон'; if (this.flow === DirectFlow.AuthBot) return 'Аккаунт бота'; if (this.flow === DirectFlow.AuthSuccess) return 'Аккаунт готов'; return 'Вход'; }
  private kicker(): string { if (this.flow === DirectFlow.AuthRegister) return 'ACCOUNT / NEW'; if (this.flow === DirectFlow.AuthEmail) return 'ACCOUNT / EMAIL'; if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) return 'ACCOUNT / OTP'; if (this.flow === DirectFlow.AuthRecovery) return 'ACCOUNT / PASSWORD'; if (this.flow === DirectFlow.AuthPhone) return 'ACCOUNT / PHONE'; if (this.flow === DirectFlow.AuthBot) return 'ACCOUNT / BOT'; if (this.flow === DirectFlow.AuthSuccess) return 'VPN DIRECT / ГОТОВО'; return 'ACCOUNT / SIGN IN'; }
  private subtitle(): string { if (this.flow === DirectFlow.AuthLogin) return 'Email, Apple, Google, телефон и код из бота — независимые аккаунты.'; if (this.flow === DirectFlow.AuthEmail) return 'Введите данные аккаунта VPN Direct.'; if (this.flow === DirectFlow.AuthCode) return this.email.length > 0 ? `Код отправлен на ${this.email}.` : 'Код отправлен на вашу почту.'; if (this.flow === DirectFlow.AuthRegister) return 'Создайте аккаунт VPN Direct.'; if (this.flow === DirectFlow.AuthRecovery) return 'Отправим ссылку для сброса пароля на вашу почту.'; if (this.flow === DirectFlow.AuthPhone) return 'Получите код подтверждения по номеру телефона.'; if (this.flow === DirectFlow.AuthBot) return 'Синхронизация аккаунта через Telegram-бота.'; if (this.flow === DirectFlow.AuthSuccess) return 'Сессия сохранена. Можно продолжить работу.'; return 'Безопасный вход и синхронизация состояния сервиса.'; }

  private async submit(): Promise<void> {
    if (this.busy) return;
    this.busy = true; this.message = '';
    try {
      if (this.flow === DirectFlow.AuthEmail) { const fn = DirectBackendRuntime.loginWithPassword; if (!fn) { this.message = 'Сервис входа недоступен'; return; } await fn(this.email.trim(), this.password); this.onFlow(DirectFlow.AuthSuccess); }
      else if (this.flow === DirectFlow.AuthRegister) { const fn = DirectBackendRuntime.registerWithPassword; if (!fn) { this.message = 'Сервис регистрации недоступен'; return; } await fn(this.name.trim(), this.email.trim(), this.password, this.confirmation); this.onFlow(DirectFlow.AuthSuccess); }
      else if (this.flow === DirectFlow.AuthRecovery) { const fn = DirectBackendRuntime.requestPasswordReset; if (!fn) { this.message = 'Восстановление недоступно'; return; } if (await fn(this.email.trim())) this.sent = true; }
      else if (this.flow === DirectFlow.AuthCode) { if (!this.sent) { const fn = DirectBackendRuntime.sendEmailCode; if (!fn) { this.message = 'Отправка кода недоступна'; return; } await fn(this.email.trim()); this.sent = true; } else { const fn = DirectBackendRuntime.verifyEmailCode; if (!fn) { this.message = 'Проверка кода недоступна'; return; } await fn(this.email.trim(), this.code.trim()); this.onFlow(DirectFlow.AuthSuccess); } }
      else if (this.flow === DirectFlow.AuthSuccess) this.onFlow(DirectFlow.Account);
      else this.message = 'Этот способ входа будет доступен после подключения соответствующего backend-провайдера.';
    } catch (err) { this.message = err instanceof Error ? err.message : `${err}`; }
    finally { this.busy = false; }
  }

  build() {
    Scroll() { Column() {
      this.header();
      Row({ space: 12 }) { Text('DIRECT').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(52).height(42).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink); Column({ space: 3 }) { Text('БЕЗОПАСНЫЙ ВХОД').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('Продолжайте с выбранным способом').fontSize(10).fontColor(DirectTheme.muted); }.alignItems(HorizontalAlign.Start).layoutWeight(1); }.width('100%').padding({ bottom: 20 });
      if (this.message.length > 0) Text(this.message).fontSize(11).fontColor(DirectTheme.danger).width('100%').padding(11).border({ width: 1, color: DirectTheme.line }).margin({ bottom: 12 });
      if (this.flow === DirectFlow.AuthLogin) this.login();
      else if (this.flow === DirectFlow.AuthEmail) this.emailLogin();
      else if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) this.codePage();
      else if (this.flow === DirectFlow.AuthRegister) this.register();
      else if (this.flow === DirectFlow.AuthRecovery) this.recovery();
      else if (this.flow === DirectFlow.AuthPhone) this.phone();
      else if (this.flow === DirectFlow.AuthBot) this.bot();
      else this.success();
      Blank().height(28);
    }.width('100%').padding({ left: 20, right: 20, bottom: 34 }); }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private header() { Row() { Column() { Text(this.kicker()).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(this.title()).fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 6 }); Text(this.subtitle()).fontSize(13).fontColor(DirectTheme.muted).margin({ top: 7 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('×').fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); }.width('100%').padding({ top: 24, bottom: 20 }).border({ width: { bottom: 1 }, color: DirectTheme.line }); }
  @Builder private input(label: string, placeholder: string, type: InputType, value: string, setter: (v:string)=>void) { Column() { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ bottom: 7 }); TextInput({ placeholder, text:value }).type(type).height(50).width('100%').fontSize(14).fontColor(DirectTheme.ink).backgroundColor('#73FFFFFF').border({ width:1, color:DirectTheme.line }).padding({ left:13,right:13 }).onChange((v:string)=>setter(v)); }.width('100%').margin({ bottom:13 }); }
  @Builder private password(label:string, placeholder:string, value:string, setter:(v:string)=>void, revealed:boolean, revealSetter:(v:boolean)=>void) { Column() { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ bottom:7 }); Row() { TextInput({ placeholder, text:value }).type(revealed ? InputType.Normal : InputType.Password).layoutWeight(1).height(50).fontSize(14).fontColor(DirectTheme.ink).backgroundColor(Color.Transparent).padding({ left:13 }); Text(revealed ? 'СКРЫТЬ' : 'ПОКАЗАТЬ').fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width(52).height(50).textAlign(TextAlign.Center).onClick(()=>{ revealSetter(!revealed); DirectHaptics.selection(); }); }.width('100%').height(50).backgroundColor('#73FFFFFF').border({ width:1,color:DirectTheme.line }).onChange((v:string)=>setter(v)); }.width('100%').margin({ bottom:13 }); }
  @Builder private primary(title:string) { Row() { Text(this.busy ? 'ОЖИДАНИЕ…' : title).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontSize(12).fontColor(DirectTheme.acid); }.width('100%').height(52).padding({ left:14,right:14 }).backgroundColor(DirectTheme.ink).onClick(()=>{ DirectHaptics.selection(); void this.submit(); }); }
  @Builder private secondary(title:string, target:DirectFlow) { Row() { Text(title).fontSize(10).fontWeight(600).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text('↗').fontSize(9).fontColor(DirectTheme.muted); }.width('100%').height(48).padding({ left:13,right:13 }).backgroundColor('#73FFFFFF').border({ width:1,color:DirectTheme.line }).onClick(()=>{ DirectHaptics.selection(); this.onFlow(target); }); }
  @Builder private login() { Column({ space:10 }) { this.secondary('ВОЙТИ ПО EMAIL',DirectFlow.AuthEmail); this.secondary('Продолжить с Apple',DirectFlow.AuthEmail); this.secondary('Продолжить с Google',DirectFlow.AuthEmail); this.secondary('По номеру телефона',DirectFlow.AuthPhone); this.secondary('Код из бота',DirectFlow.AuthBot); Row().height(1).width('100%').backgroundColor(DirectTheme.line).margin({ top:2,bottom:2 }); this.secondary('Создать аккаунт',DirectFlow.AuthRegister); Row(){Text('Не получается войти').fontSize(10).fontWeight(600).fontColor(DirectTheme.muted).height(36).textAlign(TextAlign.Center).layoutWeight(1).onClick(()=>this.onFlow(DirectFlow.AuthRecovery));}.width('100%'); }.width('100%'); }
  @Builder private emailLogin() { Column({ space:0 }) { this.input('EMAIL','you@example.com',InputType.Email,this.email,(v)=>this.email=v); this.password('ПАРОЛЬ','Введите пароль',this.password,(v)=>this.password=v,this.revealed,(v)=>this.revealed=v); Row(){Text('Забыли пароль?').fontSize(10).fontWeight(600).fontColor(DirectTheme.ink);}.width('100%').justifyContent(FlexAlign.End).height(30).onClick(()=>this.onFlow(DirectFlow.AuthRecovery)); this.primary('ВОЙТИ'); Row().height(1).width('100%').backgroundColor(DirectTheme.line).margin({ top:12,bottom:12 }); this.secondary('Войти по одноразовому коду',DirectFlow.AuthCode); this.secondary('Создать аккаунт',DirectFlow.AuthRegister); }.width('100%'); }
  @Builder private codePage() { Column({ space:0 }) { TextInput({ placeholder:'000000', text:this.code }).type(InputType.Number).height(64).width('100%').fontSize(25).fontWeight(600).fontColor(DirectTheme.ink).fontFamily('monospace').textAlign(TextAlign.Center).backgroundColor('#73FFFFFF').border({ width:1,color:DirectTheme.line }).onChange((v:string)=>this.code=v); this.primary(this.sent ? 'ПОДТВЕРДИТЬ' : 'ПОЛУЧИТЬ КОД'); Row(){Text('Отправить код снова').fontSize(10).fontWeight(600).fontColor(DirectTheme.muted).layoutWeight(1).height(42).textAlign(TextAlign.Center).onClick(()=>{this.sent=false;void this.submit();});}.width('100%'); }.width('100%'); }
  @Builder private register() { Column(){ this.input('ИМЯ','Как к вам обращаться',InputType.Normal,this.name,(v)=>this.name=v); this.input('EMAIL','you@example.com',InputType.Email,this.email,(v)=>this.email=v); this.password('ПАРОЛЬ','Минимум 8 символов',this.password,(v)=>this.password=v,this.revealed,(v)=>this.revealed=v); this.password('ПОВТОРИТЕ ПАРОЛЬ','Введите пароль ещё раз',this.confirmation,(v)=>this.confirmation=v,this.confirmationRevealed,(v)=>this.confirmationRevealed=v); Text('Создавая аккаунт, вы соглашаетесь с условиями использования и политикой конфиденциальности.').fontSize(9).fontColor(DirectTheme.muted).margin({ bottom:13 }); this.primary('СОЗДАТЬ АККАУНТ'); this.secondary('Продолжить с Apple',DirectFlow.AuthLogin); this.secondary('Продолжить с Google',DirectFlow.AuthLogin); this.secondary('По номеру телефона',DirectFlow.AuthPhone); Row(){Text('Уже есть аккаунт? Войти').fontSize(11).fontWeight(600).fontColor(DirectTheme.ink).layoutWeight(1).height(42).textAlign(TextAlign.Center).onClick(()=>this.onFlow(DirectFlow.AuthLogin));}.width('100%'); }.width('100%'); }
  @Builder private recovery() { Column(){ if(this.sent) Text('Если аккаунт существует, письмо уже отправлено. Проверьте «Спам».').fontSize(12).fontColor(DirectTheme.ink).margin({ bottom:14 }); else { this.input('EMAIL','you@example.com',InputType.Email,this.email,(v)=>this.email=v); this.primary('ОТПРАВИТЬ ССЫЛКУ'); } Text('Можно также войти через Apple, Google или по номеру.').fontSize(9).fontColor(DirectTheme.muted).margin({ bottom:12 }); this.secondary('Войти с Apple',DirectFlow.AuthLogin); this.secondary('Войти с Google',DirectFlow.AuthLogin); this.secondary('По номеру телефона',DirectFlow.AuthPhone); }.width('100%'); }
  @Builder private phone() { Column(){ this.input('ТЕЛЕФОН','+994 …',InputType.PhoneNumber,this.email,(v)=>this.email=v); this.primary('ПОЛУЧИТЬ КОД'); }.width('100%'); }
  @Builder private bot() { Column(){ Text('Код из Telegram-бота').fontSize(12).fontWeight(600).fontColor(DirectTheme.ink).margin({ bottom:8 }); this.input('КОД ИЗ БОТА','6 цифр',InputType.Number,this.code,(v)=>this.code=v); this.primary('ПОДТВЕРДИТЬ'); }.width('100%'); }
  @Builder private success() { Column({ space:16 }) { Row(){Text('OK').fontSize(22).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(64).height(64).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink);Column({space:4}){Text('ВХОД ВЫПОЛНЕН').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');Text('Сессия сохранена').fontSize(13).fontWeight(600).fontColor(DirectTheme.ink);}.alignItems(HorizontalAlign.Start).layoutWeight(1);}.width('100%'); this.primary('ГОТОВО'); }.width('100%'); }
}
