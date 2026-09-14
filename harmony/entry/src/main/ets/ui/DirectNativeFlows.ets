import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlows';

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
struct DirectNativeAction {
  @Prop title: string = '';
  @Prop destructive: boolean = false;
  @Prop onTap: () => void = () => {};
  build() {
    Row() {
      Text(this.title).fontSize(10).fontWeight(FontWeight.Bold).fontColor(this.destructive ? DirectTheme.danger : DirectTheme.acid).fontFamily('monospace');
      Blank();
      Text('→').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.destructive ? DirectTheme.danger : DirectTheme.acid);
    }.width('100%').height(52).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink)
      .onClick(() => { DirectHaptics.selection(); this.onTap(); });
  }
}

@Component
struct DirectPlansNative {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State period: string = '1 месяц';
  private readonly periods: string[] = ['1 месяц', '3 месяца', '6 месяцев', '12 месяцев'];
  private readonly plans: PlanCardData[] = [
    { name: 'START', traffic: '100 GB', devices: '1', subtitle: 'Для одного устройства', badge: '' , price: '—' },
    { name: 'PLUS', traffic: '300 GB', devices: '3', subtitle: 'Оптимальный вариант', badge: 'ПОПУЛЯРНЫЙ', price: '—' },
    { name: 'PRO', traffic: '700 GB', devices: '5', subtitle: 'Для нескольких устройств', badge: '', price: '—' },
    { name: 'MAX', traffic: '2 TB', devices: '10', subtitle: 'Большой запас трафика', badge: '', price: '—' },
    { name: 'ULTRA', traffic: '∞', devices: '20', subtitle: 'Без ограничений по трафику', badge: 'UNLIMITED', price: '—' }
  ];

  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({ kicker: 'DIRECT / PLANS', title: 'Тарифы', subtitle: 'Выберите готовый вариант и подключите его сразу', onClose: this.onClose });
        Text('ПЕРИОД').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ bottom: 8 });
        Row() {
          ForEach(this.periods, (value: string) => {
            Text(value).fontSize(9).fontWeight(FontWeight.Bold).fontColor(this.period === value ? DirectTheme.paper : DirectTheme.ink).fontFamily('monospace')
              .layoutWeight(1).height(40).textAlign(TextAlign.Center).backgroundColor(this.period === value ? DirectTheme.ink : Color.Transparent)
              .border({ width: 1, color: this.period === value ? DirectTheme.ink : DirectTheme.line })
              .onClick(() => { this.period = value; DirectHaptics.selection(); });
          });
        }.width('100%');
        Column() {
          ForEach(this.plans, (plan: PlanCardData, index: number) => {
            this.planCard(plan, index);
          });
        }.width('100%').margin({ top: 16 });
        Row() {
          Column() {
            Text('НЕ НАШЛИ ПОДХОДЯЩИЙ?').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
            Text('Собрать свой тариф').fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 4 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Text('↗').fontSize(13).fontColor(DirectTheme.ink);
        }.width('100%').height(60).padding(13).border({ width: 1, color: DirectTheme.line }).onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.Constructor); });
        Blank().height(24);
      }.padding({ left: 20, right: 20, bottom: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private planCard(plan: PlanCardData, index: number) {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(plan.name).fontSize(20).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace');
            if (plan.badge.length > 0) Text(plan.badge).fontSize(6).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').backgroundColor(DirectTheme.acid).padding({ left: 6, right: 6, top: 5, bottom: 5 }).margin({ left: 7 });
          }
          Text(plan.subtitle).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 4 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Column() { Text(plan.price).fontSize(18).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace'); Text(this.period).fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 2 }); }.alignItems(HorizontalAlign.End);
      }.width('100%');
      Row() { this.fact('ТРАФИК', plan.traffic); this.fact('УСТРОЙСТВА', plan.devices); this.fact('ДНИ', this.periodDays()); }.width('100%').padding({ top: 11, bottom: 11 }).border({ width: { top: 1 }, color: DirectTheme.line }).margin({ top: 11 });
      DirectNativeAction({ title: 'КУПИТЬ', onTap: () => this.onFlow(DirectFlow.Payment) });
    }.width('100%').padding(14).border({ width: index === 1 ? 1.5 : 1, color: index === 1 ? DirectTheme.ink : DirectTheme.line }).margin({ bottom: 10 });
  }

  @Builder
  private fact(label: string, value: string) {
    Column() { Text(label).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(value).fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 4 }); }.layoutWeight(1).alignItems(HorizontalAlign.Start);
  }

  private periodDays(): string {
    if (this.period === '3 месяца') return '90';
    if (this.period === '6 месяцев') return '180';
    if (this.period === '12 месяцев') return '365';
    return '30';
  }
}

interface PlanCardData { name: string; traffic: string; devices: string; subtitle: string; badge: string; price: string; }

@Component
struct DirectConstructorNative {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State days: number = 30;
  @State devices: number = 1;
  @State traffic: number = 100;

  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({ kicker: 'DIRECT / CONSTRUCTOR', title: 'Собрать свой тариф', subtitle: 'ДНИ · УСТРОЙСТВА · ТРАФИК', onClose: this.onClose });
        this.control('СРОК', this.days + ' ДНЕЙ');
        Slider({ value: this.days, min: 30, max: 365, step: 30 }).onChange((v: number) => this.days = Math.round(v / 30) * 30).margin({ bottom: 18 });
        this.control('УСТРОЙСТВА', String(this.devices));
        Slider({ value: this.devices, min: 1, max: 10, step: 1 }).onChange((v: number) => this.devices = Math.round(v)).margin({ bottom: 18 });
        this.control('ТРАФИК', this.traffic + ' GB');
        Slider({ value: this.traffic, min: 50, max: 2000, step: 50 }).onChange((v: number) => this.traffic = Math.round(v / 50) * 50).margin({ bottom: 20 });
        Row() { Text('РАСЧЁТ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text('—').fontSize(20).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').height(58).border({ width: { top: 1, bottom: 1 }, color: DirectTheme.line });
        DirectNativeAction({ title: 'ПРОДОЛЖИТЬ', onTap: () => this.onFlow(DirectFlow.Payment) });
        Blank().height(28);
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private control(label: string, value: string) {
    Row() { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text(value).fontSize(14).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').height(42).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }
}

@Component
struct DirectPaymentNative {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State method: string = 'Баланс';
  build() {
    Column() {
      DirectNativeChrome({ kicker: 'DIRECT / CHECKOUT', title: 'Оплата', subtitle: 'Выберите способ оплаты для выбранного сервиса.', onClose: this.onClose });
      Row() { Text('ТАРИФ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text('—').fontSize(14).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').height(42).border({ width: { bottom: 1 }, color: DirectTheme.line });
      Row() { Text('СУММА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text('—').fontSize(14).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').height(42).border({ width: { bottom: 1 }, color: DirectTheme.line });
      this.paymentOption('01', 'Оплатить с Баланса', 'Внутренний баланс', 'Баланс');
      this.paymentOption('02', 'Другие способы', 'Внешний checkout', 'Другие');
      DirectNativeAction({ title: 'ПРОДОЛЖИТЬ', onTap: () => this.onFlow(DirectFlow.PaymentProcessing) });
      Blank();
    }.padding({ left: 20, right: 20, top: 24 }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private paymentOption(index: string, title: string, detail: string, value: string) {
    Row() { Text(index).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width(30); Column() { Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Text(detail).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(this.method === value ? '●' : '○').fontSize(12).fontColor(this.method === value ? DirectTheme.green : DirectTheme.muted); }.width('100%').minHeight(58).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { this.method = value; DirectHaptics.selection(); });
  }
}

@Component
struct DirectAuthNative {
  @Prop flow: DirectFlow = DirectFlow.AuthLogin;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State email: string = '';
  @State password: string = '';
  @State phone: string = '';
  @State code: string = '';
  @State reveal: boolean = false;

  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({ kicker: 'ACCOUNT / AUTH', title: this.title(), subtitle: 'Защищённый вход и синхронизация состояния сервиса.', onClose: this.onClose });
        Row() { Text('DIRECT').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(52).height(42).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink); Column() { Text('БЕЗОПАСНЫЙ ВХОД').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('Продолжайте с выбранным способом').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1); }.width('100%').margin({ bottom: 20 });
        if (this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.AuthEmail) {
          this.field('EMAIL', 'Email', InputType.Email);
          if (this.flow === DirectFlow.AuthEmail) this.field('ПАРОЛЬ', 'Пароль', InputType.Password);
          DirectNativeAction({ title: this.flow === DirectFlow.AuthLogin ? 'ПРОДОЛЖИТЬ' : 'ВОЙТИ', onTap: () => this.onFlow(this.flow === DirectFlow.AuthLogin ? DirectFlow.AuthEmail : DirectFlow.AuthCode) });
          this.secondary('Телефон', 'Войти по номеру телефона', () => this.onFlow(DirectFlow.AuthPhone));
          this.secondary('Код бота', 'Войти по коду из Telegram-бота', () => this.onFlow(DirectFlow.AuthBot));
          this.secondary('Создать аккаунт', 'Регистрация нового аккаунта', () => this.onFlow(DirectFlow.AuthRegister));
          this.secondary('Не помню доступ', 'Восстановление', () => this.onFlow(DirectFlow.AuthRecovery));
        } else if (this.flow === DirectFlow.AuthRegister || this.flow === DirectFlow.AuthRecovery) {
          this.field('EMAIL', 'Email', InputType.Email);
          DirectNativeAction({ title: this.flow === DirectFlow.AuthRegister ? 'СОЗДАТЬ АККАУНТ' : 'ВОССТАНОВИТЬ ДОСТУП', onTap: () => this.onFlow(DirectFlow.AuthCode) });
        } else if (this.flow === DirectFlow.AuthBot) {
          Text('Откройте бота VPN Direct и введите код, который отображается в приложении.').fontSize(13).fontColor(DirectTheme.ink).width('100%').margin({ bottom: 16 });
          this.field('КОД', 'Код бота', InputType.Normal);
          DirectNativeAction({ title: 'ПОДТВЕРДИТЬ', onTap: () => this.onFlow(DirectFlow.AuthSuccess) });
        } else if (this.flow === DirectFlow.AuthPhone) {
          this.field('ТЕЛЕФОН', '+994 …', InputType.PhoneNumber);
          DirectNativeAction({ title: 'ПОЛУЧИТЬ КОД', onTap: () => this.onFlow(DirectFlow.AuthPhoneCode) });
        } else if (this.flow === DirectFlow.AuthPhoneCode || this.flow === DirectFlow.AuthCode) {
          this.field('КОД', this.flow === DirectFlow.AuthPhoneCode ? 'Код из SMS' : 'Код подтверждения', InputType.Number);
          DirectNativeAction({ title: 'ПОДТВЕРДИТЬ', onTap: () => this.onFlow(DirectFlow.AuthSuccess) });
        } else {
          Text('Доступ подтверждён').fontSize(21).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%').margin({ bottom: 8 });
          Text('Аккаунт подключён к приложению.').fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 18 });
          DirectNativeAction({ title: 'К АККАУНТУ', onTap: () => this.onFlow(DirectFlow.Account) });
        }
        Blank().height(28);
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private field(label: string, placeholder: string, inputType: InputType) {
    Column() {
      Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ bottom: 7 });
      TextInput({ placeholder: placeholder }).type(inputType).height(50).width('100%').fontSize(14).fontColor(DirectTheme.ink)
        .backgroundColor('#73FFFFFF').border({ width: 1, color: DirectTheme.line }).padding({ left: 13, right: 13 }).margin({ bottom: 14 });
    }.width('100%');
  }

  @Builder
  private secondary(title: string, detail: string, action: () => void) {
    Row() { Column() { Text(title).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text(detail).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('↗').fontSize(10).fontColor(DirectTheme.muted); }.width('100%').minHeight(48).padding({ left: 13, right: 13 }).border({ width: 1, color: DirectTheme.line }).margin({ bottom: 8 }).onClick(() => { DirectHaptics.selection(); action(); });
  }

  private title(): string {
    if (this.flow === DirectFlow.AuthLogin) return 'Войти';
    if (this.flow === DirectFlow.AuthEmail) return 'Войти по email';
    if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) return 'Подтверждение';
    if (this.flow === DirectFlow.AuthRegister) return 'Регистрация';
    if (this.flow === DirectFlow.AuthRecovery) return 'Восстановление';
    if (this.flow === DirectFlow.AuthBot) return 'Код бота';
    if (this.flow === DirectFlow.AuthPhone) return 'Телефон';
    return 'Готово';
  }
}

@Component
struct DirectSettingsNative {
  @Prop flow: DirectFlow = DirectFlow.Security;
  @Prop onClose: () => void = () => {};
  @State autoConnect: boolean = true;
  @State secureDNS: boolean = true;
  @State localNetwork: boolean = false;
  @State unknownWiFi: boolean = false;
  @State appLock: boolean = false;

  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({ kicker: 'PROFILE / SETTINGS', title: this.title(), subtitle: this.subtitle(), onClose: this.onClose });
        if (this.flow === DirectFlow.Security) {
          this.section('01 / СОЕДИНЕНИЕ', 'РЕКОМЕНДУЕТСЯ');
          this.toggleRow('Автоподключение', 'Восстанавливать соединение автоматически', this.autoConnect, (v: boolean) => this.autoConnect = v);
          this.toggleRow('Неизвестные Wi‑Fi', 'Включать VPN в новых сетях', this.unknownWiFi, (v: boolean) => this.unknownWiFi = v);
          this.section('02 / ПРИВАТНОСТЬ', 'DNS');
          this.toggleRow('Защищённый DNS', 'Блокировка утечек и опасных доменов', this.secureDNS, (v: boolean) => this.secureDNS = v);
          this.toggleRow('Локальная сеть', 'Принтеры, AirPlay и домашние устройства', this.localNetwork, (v: boolean) => this.localNetwork = v);
          this.toggleRow('Блокировка приложения', 'Запрашивать биометрическую защиту при открытии', this.appLock, (v: boolean) => this.appLock = v);
        } else {
          this.section('01 / СОСТОЯНИЕ', 'DIRECT');
          this.row('СОЕДИНЕНИЕ', 'Нативный HarmonyOS VPN extension', 'ON');
          this.row('CORE', 'VPN Direct Core / sing-box adapter', 'PINNED');
          this.row('ТУННЕЛЬ', 'TUN file descriptor → native core', '—');
          this.row('DNS', 'Конфигурация текущего профиля', '—');
          this.row('MTU', 'Размер пакета туннеля', '—');
          this.row('ЖУРНАЛ', 'Диагностическая информация', '→');
        }
        Blank().height(28);
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private section(title: string, meta: string) {
    Row() { Text(title).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text(meta).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(34).border({ width: { top: 1 }, color: DirectTheme.ink }).margin({ top: 8 });
  }

  @Builder
  private toggleRow(title: string, subtitle: string, value: boolean, setValue: (value: boolean) => void) {
    Row() { Column() { Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Text(subtitle).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 5 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: value }).selectedColor(DirectTheme.green).onChange((v: boolean) => { DirectHaptics.selection(); setValue(v); }); }.width('100%').minHeight(64).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }

  @Builder
  private row(label: string, detail: string, value: string) {
    Row() { Column() { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(detail).fontSize(12).fontColor(DirectTheme.ink).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(value).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').minHeight(58).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }

  private title(): string {
    if (this.flow === DirectFlow.Security) return 'Безопасность';
    if (this.flow === DirectFlow.Connection) return 'Подключение';
    if (this.flow === DirectFlow.Diagnostics) return 'Диагностика';
    if (this.flow === DirectFlow.Activity) return 'Мои серверы';
    if (this.flow === DirectFlow.SystemSettings) return 'Системные настройки';
    if (this.flow === DirectFlow.ApplicationSettings) return 'Настройки приложения';
    if (this.flow === DirectFlow.CoreSettings) return 'Core';
    if (this.flow === DirectFlow.TunnelSettings) return 'Туннель';
    return 'Автоподключение';
  }

  private subtitle(): string {
    if (this.flow === DirectFlow.Security) return 'Автоподключение, DNS и маршрутизация';
    if (this.flow === DirectFlow.Connection) return 'Протокол, failover и параметры соединения';
    if (this.flow === DirectFlow.Diagnostics) return 'Проверка и автоматическое исправление';
    return 'Служебные параметры VPN Direct';
  }
}

@Component
struct DirectNativeFallback {
  @Prop flow: DirectFlow = DirectFlow.None;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    Column() {
      DirectNativeChrome({ kicker: 'DIRECT', title: this.name(), subtitle: 'Раздел DirectUI перенесён в нативный ArkUI слой.', onClose: this.onClose });
      Text('Состояние').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%').margin({ bottom: 5 });
      Text('Готово к подключению реального backend/state adapter.').fontSize(13).fontColor(DirectTheme.ink).width('100%').margin({ bottom: 18 });
      DirectNativeAction({ title: 'НАЗАД', onTap: this.onClose });
      Blank();
    }.padding({ left: 20, right: 20, top: 24 }).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  private name(): string {
    if (this.flow === DirectFlow.Account) return 'Аккаунт';
    if (this.flow === DirectFlow.Balance) return 'Баланс';
    if (this.flow === DirectFlow.Subscription) return 'Подписка';
    if (this.flow === DirectFlow.ImportFile) return 'Импорт файла';
    if (this.flow === DirectFlow.ImportText) return 'Импорт текста';
    if (this.flow === DirectFlow.Legal) return 'Юридическая информация';
    if (this.flow === DirectFlow.Privacy) return 'Конфиденциальность';
    return 'Direct';
  }
}
