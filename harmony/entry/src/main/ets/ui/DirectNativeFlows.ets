import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';

@Component
export struct DirectNativeFlowHost {
  @Prop flow: DirectFlow = DirectFlow.None;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

  build() {
    if (this.flow === DirectFlow.Plans) {
      DirectPlansNative({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Constructor) {
      DirectConstructorNative({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Payment) {
      DirectPaymentNative({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.AuthEmail || this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthRegister || this.flow === DirectFlow.AuthRecovery || this.flow === DirectFlow.AuthBot || this.flow === DirectFlow.AuthPhone || this.flow === DirectFlow.AuthPhoneCode || this.flow === DirectFlow.AuthSuccess) {
      DirectAuthNative({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Security || this.flow === DirectFlow.Connection || this.flow === DirectFlow.Diagnostics || this.flow === DirectFlow.Activity || this.flow === DirectFlow.SystemSettings || this.flow === DirectFlow.ApplicationSettings || this.flow === DirectFlow.CoreSettings || this.flow === DirectFlow.TunnelSettings || this.flow === DirectFlow.OnDemandSettings) {
      DirectSettingsNative({ flow: this.flow, onClose: this.onClose });
    } else {
      DirectNativeFallback({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    }
  }
}

@Component
struct DirectNativeChrome {
  @Prop kicker: string = '';
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent)
          .width(36).height(36).onClick(() => { DirectHaptics.navigation(); this.onClose(); });
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
struct DirectPaymentNative {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    Column() {
      DirectNativeChrome({ kicker: 'DIRECT / ОПЕРАЦИЯ', title: 'Продолжение', subtitle: 'Переход к защищённому платёжному процессу.', onClose: this.onClose });
      Column() {
        Text('ПЛАТЁЖНЫЙ ПРОЦЕСС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
        Text('Ожидается подключение Harmony payment adapter').fontSize(16).fontColor(DirectTheme.ink).margin({ top: 8 });
        Text('UI и состояния процесса готовы; реальная транзакция не имитируется.').fontSize(11).fontColor(DirectTheme.muted).margin({ top: 6 });
      }.width('100%').padding(16).border({ width: 1, color: DirectTheme.line });
      Row() { Text('ЗАКРЫТЬ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text('→').fontColor(DirectTheme.ink); }
        .width('100%').height(52).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.acid).border({ width: 1.5, color: DirectTheme.ink }).margin({ top: 12 })
        .onClick(() => { DirectHaptics.selection(); this.onClose(); });
    }.padding({ left: 20, right: 20, top: 18 }).backgroundColor(DirectTheme.paper).width('100%').height('100%');
  }
}

@Component
struct DirectAuthNative {
  @Prop flow: DirectFlow = DirectFlow.AuthLogin;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State email: string = '';
  @State password: string = '';
  @State code: string = '';

  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({ kicker: 'ACCOUNT / AUTH', title: this.title(), subtitle: 'Безопасный вход и синхронизация состояния сервиса.', onClose: this.onClose });
        Text('EMAIL').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
        TextInput({ placeholder: 'email@example.com', text: this.email }).height(50).margin({ top: 7, bottom: 14 }).onChange(v => this.email = v);
        if (this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.AuthEmail || this.flow === DirectFlow.AuthRegister) {
          Text('ПАРОЛЬ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
          TextInput({ placeholder: 'Пароль', text: this.password }).type(InputType.Password).height(50).margin({ top: 7, bottom: 14 }).onChange(v => this.password = v);
        } else if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) {
          Text('КОД ПОДТВЕРЖДЕНИЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
          TextInput({ placeholder: '000000', text: this.code }).type(InputType.Number).height(50).margin({ top: 7, bottom: 14 }).onChange(v => this.code = v);
        }
        this.actionButton();
        if (this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.AuthEmail) {
          this.row('CODE', 'Войти по коду', 'Без постоянного пароля', () => this.onFlow(DirectFlow.AuthCode));
        }
        Blank().height(28);
      }.padding({ left: 20, right: 20, bottom: 30 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private actionButton() {
    Row() { Text(this.actionTitle()).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); Text('→').fontColor(DirectTheme.acid); }
      .width('100%').height(56).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).margin({ bottom: 12 })
      .onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.AuthSuccess); });
  }

  @Builder private row(mark: string, title: string, subtitle: string, action: () => void) {
    Row() { Text(mark).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').textAlign(TextAlign.Center).width(45).height(40).backgroundColor(DirectTheme.ink); Column() { Text(title).fontSize(13).fontColor(DirectTheme.ink); Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 }); Text('›').fontSize(20).fontColor(DirectTheme.muted); }
      .minHeight(64).width('100%').border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); action(); });
  }

  private title(): string { if (this.flow === DirectFlow.AuthRegister) return 'Регистрация'; if (this.flow === DirectFlow.AuthRecovery) return 'Восстановление'; if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) return 'Подтверждение'; if (this.flow === DirectFlow.AuthSuccess) return 'Готово'; return 'Вход'; }
  private actionTitle(): string { if (this.flow === DirectFlow.AuthRegister) return 'СОЗДАТЬ АККАУНТ'; if (this.flow === DirectFlow.AuthRecovery) return 'ПРОДОЛЖИТЬ'; if (this.flow === DirectFlow.AuthSuccess) return 'ГОТОВО'; return 'ВОЙТИ'; }
}

@Component
struct DirectSettingsNative {
  @Prop flow: DirectFlow = DirectFlow.Security;
  @Prop onClose: () => void = () => {};
  build() {
    Scroll() { Column() {
      DirectNativeChrome({ kicker: 'DIRECT / SETTINGS', title: this.title(), subtitle: 'Параметры подключения и приложения.', onClose: this.onClose });
      this.row('01', 'Статус', 'Текущее состояние VPN Direct');
      this.row('02', 'Системные настройки', 'Параметры HarmonyOS и разрешения');
      this.row('03', 'Диагностика', 'Сведения для проверки соединения');
      this.row('04', 'О приложении', 'VPN Direct · HarmonyOS');
    }.padding({ left: 20, right: 20 }) }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  @Builder private row(mark: string, title: string, subtitle: string) { Row() { Text(mark).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').textAlign(TextAlign.Center).width(45).height(40).backgroundColor(DirectTheme.ink); Column() { Text(title).fontSize(13).fontColor(DirectTheme.ink); Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 }); Text('›').fontSize(20).fontColor(DirectTheme.muted); }.minHeight(64).width('100%').border({ width: { bottom: 1 }, color: DirectTheme.line }); }
  private title(): string { if (this.flow === DirectFlow.Diagnostics) return 'Диагностика'; if (this.flow === DirectFlow.Security) return 'Безопасность'; if (this.flow === DirectFlow.Connection) return 'Соединение'; if (this.flow === DirectFlow.Activity) return 'Активность'; if (this.flow === DirectFlow.About) return 'О приложении'; return 'Настройки'; }
}

@Component
struct DirectNativeFallback {
  @Prop flow: DirectFlow = DirectFlow.None;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    Column() { DirectNativeChrome({ kicker: 'DIRECT / STATE', title: 'Состояние', subtitle: 'Операция выполняется или ожидает результата.', onClose: this.onClose });
      Text('Состояние синхронизируется с сервисом.').fontSize(13).fontColor(DirectTheme.ink).padding(18).width('100%').border({ width: 1, color: DirectTheme.line });
    }.padding({ left: 20, right: 20, top: 18 }).backgroundColor(DirectTheme.paper).width('100%').height('100%');
  }
}