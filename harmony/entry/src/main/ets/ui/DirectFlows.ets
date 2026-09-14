import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';

export enum DirectFlow {
  None,
  ServerPicker,
  ConnectionReport,
  Profiles,
  Access,
  AuthLogin,
  AuthEmail,
  AuthCode,
  AuthRegister,
  AuthRecovery,
  AuthBot,
  AuthPhone,
  AuthPhoneCode,
  AuthSuccess,
  Plans,
  Constructor,
  Payment,
  PaymentProcessing,
  PaymentWaiting,
  PaymentCancelled,
  PaymentError,
  PaymentSuccess,
  Balance,
  BalanceTopUp,
  Management,
  Subscription,
  Security,
  Connection,
  Diagnostics,
  Activity,
  SystemSettings,
  About,
  ServiceLog,
  ApplicationSettings,
  CoreSettings,
  TunnelSettings,
  OnDemandSettings,
  ImportFile,
  ImportText,
  Legal,
  Privacy,
  Account,
  Devices,
  PaymentHistory
}

@Component
export struct DirectFlowHost {
  @Prop flow: DirectFlow = DirectFlow.None;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

  build() {
    if (this.flow === DirectFlow.None) {
      Blank();
    } else if (this.flow === DirectFlow.ServerPicker) {
      DirectServerPickerFlow({ onClose: this.onClose });
    } else if (this.flow === DirectFlow.ConnectionReport) {
      DirectConnectionReportFlow({ onClose: this.onClose });
    } else if (this.flow === DirectFlow.Profiles) {
      DirectProfilesFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Access) {
      DirectAccessFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Plans) {
      DirectPlansFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Constructor) {
      DirectConstructorFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Payment) {
      DirectPaymentFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.PaymentProcessing) {
      DirectStateFlow({ code: 'PAYMENT / 01', title: 'Подтверждаем оплату', body: 'Проверяем состояние платежа и активацию сервиса.', state: FlowState.Loading, primary: 'Обновить', onPrimary: () => this.onFlow(DirectFlow.PaymentWaiting), onClose: this.onClose });
    } else if (this.flow === DirectFlow.PaymentWaiting) {
      DirectStateFlow({ code: 'PAYMENT / 02', title: 'Ожидаем подтверждение', body: 'Платёж создан. Статус обновится автоматически.', state: FlowState.Waiting, primary: 'Проверить статус', onPrimary: () => this.onFlow(DirectFlow.PaymentSuccess), onClose: this.onClose });
    } else if (this.flow === DirectFlow.PaymentCancelled) {
      DirectStateFlow({ code: 'PAYMENT / 03', title: 'Платёж отменён', body: 'Платёж не завершён. Вы можете повторить попытку или выбрать другой способ.', state: FlowState.Error, primary: 'Повторить', onPrimary: () => this.onFlow(DirectFlow.Payment), onClose: this.onClose });
    } else if (this.flow === DirectFlow.PaymentError) {
      DirectStateFlow({ code: 'PAYMENT / 04', title: 'Не удалось завершить оплату', body: 'Проверьте соединение и попробуйте ещё раз. Средства не списываются повторно автоматически.', state: FlowState.Error, primary: 'Повторить', onPrimary: () => this.onFlow(DirectFlow.Payment), onClose: this.onClose });
    } else if (this.flow === DirectFlow.PaymentSuccess) {
      DirectStateFlow({ code: 'PAYMENT / 05', title: 'Подписка активна', body: 'Сервис готов к подключению. Сервер можно выбрать на экране локаций.', state: FlowState.Success, primary: 'Открыть локации', onPrimary: () => this.onFlow(DirectFlow.ServerPicker), onClose: this.onClose });
    } else if (this.flow === DirectFlow.Balance) {
      DirectBalanceFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.BalanceTopUp) {
      DirectBalanceTopUpFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Subscription) {
      DirectSubscriptionFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Security || this.flow === DirectFlow.Connection || this.flow === DirectFlow.Diagnostics || this.flow === DirectFlow.Activity || this.flow === DirectFlow.SystemSettings || this.flow === DirectFlow.ApplicationSettings || this.flow === DirectFlow.CoreSettings || this.flow === DirectFlow.TunnelSettings || this.flow === DirectFlow.OnDemandSettings) {
      DirectSettingsFlow({ flow: this.flow, onClose: this.onClose });
    } else if (this.flow === DirectFlow.Legal || this.flow === DirectFlow.Privacy) {
      DirectLegalFlow({ privacy: this.flow === DirectFlow.Privacy, onClose: this.onClose });
    } else if (this.flow === DirectFlow.ImportFile || this.flow === DirectFlow.ImportText) {
      DirectImportFlow({ textMode: this.flow === DirectFlow.ImportText, onClose: this.onClose });
    } else if (this.flow === DirectFlow.Account || this.flow === DirectFlow.Devices || this.flow === DirectFlow.PaymentHistory) {
      DirectAccountFlow({ flow: this.flow, onClose: this.onClose });
    } else if (this.flow === DirectFlow.Management) {
      DirectManagementFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.AuthEmail || this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthRegister || this.flow === DirectFlow.AuthRecovery || this.flow === DirectFlow.AuthBot || this.flow === DirectFlow.AuthPhone || this.flow === DirectFlow.AuthPhoneCode || this.flow === DirectFlow.AuthSuccess) {
      DirectAuthFlow({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    }
  }
}

enum FlowState { Loading, Waiting, Error, Success }

@Component
struct DirectFlowChrome {
  @Prop code: string = '';
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).onClick(() => { DirectHaptics.navigation(); this.onClose(); });
        Column() {
          Text(this.code).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Text(this.title).fontSize(24).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 5 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      }.width('100%').height(62).alignItems(VerticalAlign.Center);
      Text(this.subtitle).fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 18 });
    }.width('100%');
  }
}

@Component
struct DirectRow {
  @Prop index: string = '01';
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop trailing: string = '→';
  @Prop onTap: () => void = () => {};

  build() {
    Row() {
      Text(this.index).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width(30);
      Column() {
        Text(this.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%');
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(11).fontColor(DirectTheme.muted).width('100%').margin({ top: 3 });
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Text(this.trailing).fontSize(15).fontColor(DirectTheme.muted);
    }.width('100%').minHeight(58).padding({ left: 13, right: 13, top: 10, bottom: 10 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); this.onTap(); });
  }
}

@Component
struct DirectServerPickerFlow {
  @Prop onClose: () => void = () => {};
  @State private selected: string = 'Авто';
  private servers: string[] = ['Авто', 'Germany / Frankfurt', 'Netherlands / Amsterdam', 'Finland / Helsinki', 'Sweden / Stockholm', 'Armenia / Yerevan'];
  build() {
    Scroll() {
      Column() {
        DirectFlowChrome({ code: 'LOCATIONS / 01', title: 'Сервер', subtitle: 'Выберите точку подключения. «Авто» выбирает оптимальную.' , onClose: this.onClose });
        ForEach(this.servers, (name: string, index: number) => {
          DirectRow({ index: String(index + 1).padStart(2, '0'), title: name, subtitle: index === 0 ? 'Автоматический выбор' : 'Доступен', trailing: name === this.selected ? '●' : '○', onTap: () => this.selected = name });
        });
      }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, bottom: 30 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectConnectionReportFlow {
  @Prop onClose: () => void = () => {};
  build() {
    Column() {
      DirectFlowChrome({ code: 'CONNECTION / 01', title: 'Отчёт подключения', subtitle: 'Текущее состояние туннеля и выбранного сервера.', onClose: this.onClose });
      Row() { Text('●').fontColor(DirectTheme.green); Text(' СОЕДИНЕНИЕ СТАБИЛЬНО').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').margin({ bottom: 16 });
      DirectMetric({ label: 'СЕРВЕР', value: 'Авто' });
      DirectMetric({ label: 'ЗАДЕРЖКА', value: '— MS' });
      DirectMetric({ label: 'СЕССИЯ', value: 'АКТИВНА' });
      DirectMetric({ label: 'ТРАФИК', value: '0 B' });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 24 }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectMetric {
  @Prop label: string = '';
  @Prop value: string = '';
  build() {
    Row() { Text(this.label).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text(this.value).fontSize(13).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').height(42).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }
}

@Component
struct DirectProfilesFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State private selected: number = 0;
  build() {
    Column() {
      DirectFlowChrome({ code: 'PROFILES / 01', title: 'Профили', subtitle: 'Подписки и локальные конфигурации устройства.', onClose: this.onClose });
      DirectRow({ index: '01', title: 'VPN Direct', subtitle: 'Активный профиль', trailing: this.selected === 0 ? '●' : '○', onTap: () => this.selected = 0 });
      DirectRow({ index: '02', title: 'Добавить профиль', subtitle: 'Импортировать или создать конфигурацию', onTap: () => this.onFlow(DirectFlow.ImportText) });
      DirectRow({ index: '03', title: 'Серверы', subtitle: 'Выбрать точку подключения', onTap: () => this.onFlow(DirectFlow.ServerPicker) });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectAccessFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    Column() {
      DirectFlowChrome({ code: 'ACCESS / 01', title: 'Доступ', subtitle: 'Выберите способ подключить сервис к этому устройству.', onClose: this.onClose });
      DirectRow({ index: '01', title: 'Войти в аккаунт', subtitle: 'Синхронизировать подписки и баланс', onTap: () => this.onFlow(DirectFlow.AuthLogin) });
      DirectRow({ index: '02', title: 'Импортировать подписку', subtitle: 'Ссылка, QR, файл или текст конфигурации', onTap: () => this.onFlow(DirectFlow.ImportText) });
      DirectRow({ index: '03', title: 'Тарифы', subtitle: 'Посмотреть доступные варианты сервиса', onTap: () => this.onFlow(DirectFlow.Plans) });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectAuthFlow {
  @Prop flow: DirectFlow = DirectFlow.AuthLogin;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State private email: string = '';
  @State private code: string = '';
  @State private phone: string = '';

  build() {
    Scroll() {
      Column() {
        DirectFlowChrome({ code: 'ACCOUNT / AUTH', title: this.title(), subtitle: this.subtitle(), onClose: this.onClose });
        if (this.flow === DirectFlow.AuthLogin) {
          TextInput({ placeholder: 'Email' }).type(InputType.Email).height(48).backgroundColor(Color.Transparent).border({ width: 1, color: DirectTheme.line }).onChange((v: string) => this.email = v);
          DirectAction({ title: 'Продолжить', onTap: () => this.onFlow(DirectFlow.AuthEmail) });
          DirectRow({ index: '02', title: 'Телефон', subtitle: 'Войти по номеру телефона', onTap: () => this.onFlow(DirectFlow.AuthPhone) });
          DirectRow({ index: '03', title: 'Код бота', subtitle: 'Войти по коду из Telegram-бота', onTap: () => this.onFlow(DirectFlow.AuthBot) });
          DirectRow({ index: '04', title: 'Создать аккаунт', subtitle: 'Регистрация нового аккаунта', onTap: () => this.onFlow(DirectFlow.AuthRegister) });
          DirectRow({ index: '05', title: 'Не помню доступ', subtitle: 'Восстановление', onTap: () => this.onFlow(DirectFlow.AuthRecovery) });
        } else if (this.flow === DirectFlow.AuthEmail) {
          TextInput({ text: this.email, placeholder: 'Email' }).type(InputType.Email).height(48).backgroundColor(Color.Transparent).border({ width: 1, color: DirectTheme.line });
          DirectAction({ title: 'Получить код', onTap: () => this.onFlow(DirectFlow.AuthCode) });
        } else if (this.flow === DirectFlow.AuthCode) {
          TextInput({ placeholder: 'Код подтверждения' }).type(InputType.Number).height(48).backgroundColor(Color.Transparent).border({ width: 1, color: DirectTheme.line }).onChange((v: string) => this.code = v);
          DirectAction({ title: 'Подтвердить', onTap: () => this.onFlow(DirectFlow.AuthSuccess) });
        } else if (this.flow === DirectFlow.AuthRegister) {
          TextInput({ placeholder: 'Email' }).type(InputType.Email).height(48).backgroundColor(Color.Transparent).border({ width: 1, color: DirectTheme.line });
          DirectAction({ title: 'Создать аккаунт', onTap: () => this.onFlow(DirectFlow.AuthCode) });
        } else if (this.flow === DirectFlow.AuthRecovery) {
          TextInput({ placeholder: 'Email' }).type(InputType.Email).height(48).backgroundColor(Color.Transparent).border({ width: 1, color: DirectTheme.line });
          DirectAction({ title: 'Восстановить доступ', onTap: () => this.onFlow(DirectFlow.AuthCode) });
        } else if (this.flow === DirectFlow.AuthBot) {
          Text('Откройте бота VPN Direct и введите код, который отображается в приложении.').fontSize(13).fontColor(DirectTheme.ink).width('100%').margin({ bottom: 16 });
          DirectAction({ title: 'Ввести код', onTap: () => this.onFlow(DirectFlow.AuthCode) });
        } else if (this.flow === DirectFlow.AuthPhone) {
          TextInput({ placeholder: '+994 …' }).type(InputType.PhoneNumber).height(48).backgroundColor(Color.Transparent).border({ width: 1, color: DirectTheme.line }).onChange((v: string) => this.phone = v);
          DirectAction({ title: 'Получить код', onTap: () => this.onFlow(DirectFlow.AuthPhoneCode) });
        } else if (this.flow === DirectFlow.AuthPhoneCode) {
          TextInput({ placeholder: 'Код из SMS' }).type(InputType.Number).height(48).backgroundColor(Color.Transparent).border({ width: 1, color: DirectTheme.line });
          DirectAction({ title: 'Подтвердить', onTap: () => this.onFlow(DirectFlow.AuthSuccess) });
        } else if (this.flow === DirectFlow.AuthSuccess) {
          DirectStateMark({ state: FlowState.Success, title: 'Доступ подтверждён', body: 'Аккаунт подключён к приложению.' });
          DirectAction({ title: 'К аккаунту', onTap: () => this.onFlow(DirectFlow.Account) });
        }
        Blank();
      }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, bottom: 30 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  private title(): string {
    if (this.flow === DirectFlow.AuthLogin) return 'Войти';
    if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) return 'Подтверждение';
    if (this.flow === DirectFlow.AuthRegister) return 'Регистрация';
    if (this.flow === DirectFlow.AuthRecovery) return 'Восстановление';
    if (this.flow === DirectFlow.AuthBot) return 'Код бота';
    if (this.flow === DirectFlow.AuthPhone) return 'Телефон';
    if (this.flow === DirectFlow.AuthSuccess) return 'Готово';
    return 'Email';
  }
  private subtitle(): string { return 'Защищённый вход и синхронизация состояния сервиса.'; }
}

@Component
struct DirectPlansFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State private selected: string = '1 месяц';
  build() {
    Column() {
      DirectFlowChrome({ code: 'PLANS / 01', title: 'Тарифы', subtitle: 'Выберите срок сервиса. Финальная сумма показывается перед оплатой.', onClose: this.onClose });
      ForEach(['1 месяц', '3 месяца', '6 месяцев', '12 месяцев'], (period: string, index: number) => {
        DirectRow({ index: String(index + 1).padStart(2, '0'), title: period, subtitle: index === 0 ? 'Базовый вариант' : 'Продлённый срок', trailing: period === this.selected ? '●' : '○', onTap: () => this.selected = period });
      });
      DirectAction({ title: 'Продолжить', onTap: () => this.onFlow(DirectFlow.Payment) });
      DirectRow({ index: '05', title: 'Конструктор', subtitle: 'Настроить срок, устройства и трафик', onTap: () => this.onFlow(DirectFlow.Constructor) });
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectConstructorFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State private days: number = 30;
  @State private devices: number = 1;
  @State private traffic: number = 100;
  build() {
    Column() {
      DirectFlowChrome({ code: 'PLANS / 02', title: 'Конструктор', subtitle: 'Соберите сервис под количество устройств и объём трафика.', onClose: this.onClose });
      DirectMetric({ label: 'СРОК', value: this.days + ' ДНЕЙ' });
      Slider({ value: this.days, min: 30, max: 365, step: 30 }).onChange((v: number) => this.days = Math.round(v / 30) * 30).margin({ top: 8, bottom: 12 });
      DirectMetric({ label: 'УСТРОЙСТВА', value: String(this.devices) });
      Slider({ value: this.devices, min: 1, max: 10, step: 1 }).onChange((v: number) => this.devices = Math.round(v));
      DirectMetric({ label: 'ТРАФИК', value: this.traffic + ' GB' });
      Slider({ value: this.traffic, min: 50, max: 1000, step: 50 }).onChange((v: number) => this.traffic = Math.round(v / 50) * 50);
      Blank();
      DirectAction({ title: 'Рассчитать', onTap: () => this.onFlow(DirectFlow.Payment) });
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 24 }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectPaymentFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State private method: string = 'Баланс';
  build() {
    Column() {
      DirectFlowChrome({ code: 'PAYMENT / 00', title: 'Оплата', subtitle: 'Выберите способ оплаты для выбранного сервиса.', onClose: this.onClose });
      DirectMetric({ label: 'ТАРИФ', value: '1 МЕСЯЦ' });
      DirectMetric({ label: 'СУММА', value: '—' });
      DirectRow({ index: '01', title: 'Оплатить с Баланса', subtitle: 'Внутренний баланс', trailing: this.method === 'Баланс' ? '●' : '○', onTap: () => this.method = 'Баланс' });
      DirectRow({ index: '02', title: 'Другие способы', subtitle: 'Внешний checkout', trailing: this.method === 'Другие' ? '●' : '○', onTap: () => this.method = 'Другие' });
      DirectAction({ title: 'Продолжить', onTap: () => this.onFlow(DirectFlow.PaymentProcessing) });
      DirectRow({ index: '03', title: 'Баланс', subtitle: 'Посмотреть состояние счёта', onTap: () => this.onFlow(DirectFlow.Balance) });
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectBalanceFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    Column() {
      DirectFlowChrome({ code: 'BALANCE / 01', title: 'Баланс', subtitle: 'Средства, доступные для сервиса и оплаты тарифа.', onClose: this.onClose });
      Text('—').fontSize(42).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%');
      Text('USD').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%').margin({ top: 3, bottom: 18 });
      DirectAction({ title: 'Пополнить баланс', onTap: () => this.onFlow(DirectFlow.BalanceTopUp) });
      DirectRow({ index: '02', title: 'История платежей', subtitle: 'Операции по аккаунту', onTap: () => this.onFlow(DirectFlow.PaymentHistory) });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectBalanceTopUpFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State private amount: number = 10;
  build() {
    Column() {
      DirectFlowChrome({ code: 'BALANCE / 02', title: 'Пополнение', subtitle: 'Выберите сумму и перейдите к защищённому checkout.', onClose: this.onClose });
      ForEach(['5 USD', '10 USD', '25 USD', '50 USD'], (v: string, index: number) => DirectRow({ index: String(index + 1).padStart(2, '0'), title: v, subtitle: 'Пополнение баланса', onTap: () => this.amount = [5, 10, 25, 50][index] }));
      DirectAction({ title: 'Продолжить', onTap: () => this.onFlow(DirectFlow.PaymentProcessing) });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectSubscriptionFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    Column() {
      DirectFlowChrome({ code: 'SERVICE / 01', title: 'Подписка', subtitle: 'Состояние срока, трафика и устройств текущего сервиса.', onClose: this.onClose });
      DirectMetric({ label: 'СТАТУС', value: '—' });
      DirectMetric({ label: 'СРОК', value: '—' });
      DirectMetric({ label: 'ТРАФИК', value: '—' });
      DirectMetric({ label: 'УСТРОЙСТВА', value: '—' });
      DirectAction({ title: 'Продлить', onTap: () => this.onFlow(DirectFlow.Plans) });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectManagementFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    Column() {
      DirectFlowChrome({ code: 'MANAGEMENT / 01', title: 'Управление', subtitle: 'Сервис, подписки, профили и диагностика.', onClose: this.onClose });
      DirectRow({ index: '01', title: 'Активная подписка', subtitle: 'Срок, трафик, устройства', onTap: () => this.onFlow(DirectFlow.Subscription) });
      DirectRow({ index: '02', title: 'Профили', subtitle: 'Конфигурации и импорт', onTap: () => this.onFlow(DirectFlow.Profiles) });
      DirectRow({ index: '03', title: 'Тарифы', subtitle: 'Продление и конструктор', onTap: () => this.onFlow(DirectFlow.Plans) });
      DirectRow({ index: '04', title: 'Баланс', subtitle: 'Счёт и пополнение', onTap: () => this.onFlow(DirectFlow.Balance) });
      DirectRow({ index: '05', title: 'Доступ', subtitle: 'Аккаунт или импорт', onTap: () => this.onFlow(DirectFlow.Access) });
      DirectRow({ index: '06', title: 'Диагностика', subtitle: 'Состояние VPN Direct Core', onTap: () => this.onFlow(DirectFlow.Diagnostics) });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectSettingsFlow {
  @Prop flow: DirectFlow = DirectFlow.Security;
  @Prop onClose: () => void = () => {};
  build() {
    Column() {
      DirectFlowChrome({ code: 'SETTINGS / 01', title: this.title(), subtitle: 'Нативные настройки HarmonyOS для VPN Direct.', onClose: this.onClose });
      DirectRow({ index: '01', title: 'Состояние', subtitle: 'Текущая конфигурация', trailing: 'ON' });
      DirectRow({ index: '02', title: 'Автоподключение', subtitle: 'Поведение при запуске', trailing: '—' });
      DirectRow({ index: '03', title: 'DNS', subtitle: 'Параметры разрешения имён', trailing: '—' });
      DirectRow({ index: '04', title: 'MTU', subtitle: 'Размер пакета туннеля', trailing: '—' });
      DirectRow({ index: '05', title: 'Журнал', subtitle: 'Диагностическая информация', trailing: '→' });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  private title(): string {
    if (this.flow === DirectFlow.Security) return 'Безопасность';
    if (this.flow === DirectFlow.Connection) return 'Подключение';
    if (this.flow === DirectFlow.Diagnostics) return 'Диагностика';
    if (this.flow === DirectFlow.Activity) return 'Активность';
    if (this.flow === DirectFlow.SystemSettings) return 'Системные настройки';
    if (this.flow === DirectFlow.ApplicationSettings) return 'Настройки приложения';
    if (this.flow === DirectFlow.CoreSettings) return 'Core';
    if (this.flow === DirectFlow.TunnelSettings) return 'Туннель';
    if (this.flow === DirectFlow.OnDemandSettings) return 'Автоподключение';
    return 'Настройки';
  }
}

@Component
struct DirectImportFlow {
  @Prop textMode: boolean = false;
  @Prop onClose: () => void = () => {};
  @State private value: string = '';
  build() {
    Column() {
      DirectFlowChrome({ code: 'IMPORT / 01', title: this.textMode ? 'Вставить конфиг' : 'Импорт файла', subtitle: 'Данные конфигурации импортируются как профиль. Код приложения не изменяется.', onClose: this.onClose });
      if (this.textMode) {
        TextArea({ placeholder: 'Вставьте JSON, YAML или URI…', text: this.value }).height(180).backgroundColor(Color.Transparent).border({ width: 1, color: DirectTheme.line }).onChange((v: string) => this.value = v);
      } else {
        DirectStateMark({ state: FlowState.Waiting, title: 'Выберите файл', body: 'Поддерживаемый файл будет разобран и добавлен как профиль.' });
      }
      DirectAction({ title: this.textMode ? 'Импортировать' : 'Выбрать файл', onTap: () => { DirectHaptics.success(); this.onClose(); } });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 24 }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectLegalFlow {
  @Prop privacy: boolean = false;
  @Prop onClose: () => void = () => {};
  build() {
    Scroll() {
      Column() {
        DirectFlowChrome({ code: 'LEGAL / 01', title: this.privacy ? 'Конфиденциальность' : 'Правовая информация', subtitle: 'Условия и правила использования VPN Direct.', onClose: this.onClose });
        Text(this.privacy ? 'ПОЛИТИКА КОНФИДЕНЦИАЛЬНОСТИ' : 'УСЛОВИЯ ИСПОЛЬЗОВАНИЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
        Text('VPN Direct обрабатывает только данные, необходимые для работы приложения, управления профилями и предоставления сетевого сервиса. Конкретные юридические тексты должны быть синхронизированы с опубликованной политикой продукта.').fontSize(13).fontColor(DirectTheme.ink).lineHeight(20).width('100%').margin({ top: 10 });
        Text('Версия документа').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 26, bottom: 5 });
        Text('1.0').fontSize(13).fontColor(DirectTheme.ink);
        Blank();
      }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, bottom: 30 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectAccountFlow {
  @Prop flow: DirectFlow = DirectFlow.Account;
  @Prop onClose: () => void = () => {};
  build() {
    Column() {
      DirectFlowChrome({ code: 'ACCOUNT / 01', title: this.title(), subtitle: 'Управление аккаунтом и связанными данными.', onClose: this.onClose });
      if (this.flow === DirectFlow.Account) {
        DirectMetric({ label: 'EMAIL', value: '—' });
        DirectRow({ index: '01', title: 'Устройства', subtitle: 'Управление активными устройствами' });
        DirectRow({ index: '02', title: 'Платежи', subtitle: 'История операций' });
      } else if (this.flow === DirectFlow.Devices) {
        DirectRow({ index: '01', title: 'Это устройство', subtitle: 'HarmonyOS / текущая сессия', trailing: '●' });
      } else {
        DirectRow({ index: '01', title: 'Платёж', subtitle: 'История загружается', trailing: '—' });
      }
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  private title(): string { return this.flow === DirectFlow.Devices ? 'Устройства' : this.flow === DirectFlow.PaymentHistory ? 'Платежи' : 'Аккаунт'; }
}

@Component
struct DirectStateFlow {
  @Prop code: string = '';
  @Prop title: string = '';
  @Prop body: string = '';
  @Prop state: FlowState = FlowState.Waiting;
  @Prop primary: string = '';
  @Prop onPrimary: () => void = () => {};
  @Prop onClose: () => void = () => {};
  build() {
    Column() {
      DirectFlowChrome({ code: this.code, title: this.title, subtitle: this.body, onClose: this.onClose });
      DirectStateMark({ state: this.state, title: this.title, body: this.body });
      DirectAction({ title: this.primary, onTap: this.onPrimary });
      Blank();
    }.padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
}

@Component
struct DirectStateMark {
  @Prop state: FlowState = FlowState.Waiting;
  @Prop title: string = '';
  @Prop body: string = '';
  build() {
    Column() {
      Text(this.state === FlowState.Success ? '✓' : this.state === FlowState.Error ? '!' : this.state === FlowState.Loading ? '…' : '○').fontSize(42).fontWeight(FontWeight.Bold).fontColor(this.state === FlowState.Error ? DirectTheme.danger : this.state === FlowState.Success ? DirectTheme.green : DirectTheme.ink);
      Text(this.state === FlowState.Loading ? 'ЗАГРУЗКА' : this.state === FlowState.Waiting ? 'ОЖИДАНИЕ' : this.state === FlowState.Error ? 'ОШИБКА' : 'ГОТОВО').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 8 });
      Text(this.body).fontSize(13).fontColor(DirectTheme.ink).lineHeight(19).width('100%').margin({ top: 12 });
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 18 });
  }
}

@Component
struct DirectAction {
  @Prop title: string = '';
  @Prop onTap: () => void = () => {};
  build() {
    Button(this.title).width('100%').height(48).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.paper).backgroundColor(DirectTheme.ink).borderRadius(0).margin({ top: 16, bottom: 10 }).onClick(() => { DirectHaptics.selection(); this.onTap(); });
  }
}
