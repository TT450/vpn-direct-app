import { DirectTheme } from './Theme';
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
    } else if (this.flow >= DirectFlow.AuthLogin && this.flow <= DirectFlow.AuthSuccess) {
      DirectAuthNative({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow >= DirectFlow.Security && this.flow <= DirectFlow.OnDemandSettings) {
      DirectSettingsNative({ flow: this.flow, onClose: this.onClose });
    } else {
      DirectNativeFallback({ flow: this.flow, onClose: this.onClose });
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
          .width(36).height(36)
          .onClick(() => { DirectHaptics.navigation(); this.onClose(); });
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
  @Prop onTap: () => void = () => {};

  build() {
    Row() {
      Text(this.title).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace');
      Blank();
      Text('→').fontSize(12).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid);
    }.width('100%').height(52).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink)
      .onClick(() => { DirectHaptics.selection(); this.onTap(); });
  }
}

interface PlanCardData { name: string; traffic: string; devices: string; subtitle: string; badge: string; }

@Component
struct DirectPlansNative {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State period: string = '1 месяц';
  private readonly periods: string[] = ['1 месяц', '3 месяца', '6 месяцев', '12 месяцев'];
  private readonly plans: PlanCardData[] = [
    { name: 'START', traffic: '100 GB', devices: '1', subtitle: 'Для одного устройства', badge: '' },
    { name: 'PLUS', traffic: '300 GB', devices: '3', subtitle: 'Оптимальный вариант', badge: 'ПОПУЛЯРНЫЙ' },
    { name: 'PRO', traffic: '700 GB', devices: '5', subtitle: 'Для нескольких устройств', badge: '' },
    { name: 'MAX', traffic: '2 TB', devices: '10', subtitle: 'Большой запас трафика', badge: '' },
    { name: 'ULTRA', traffic: '∞', devices: '20', subtitle: 'Без ограничений по трафику', badge: 'UNLIMITED' }
  ];

  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({ kicker: 'DIRECT / PLANS', title: 'Тарифы', subtitle: 'Выберите готовый вариант', onClose: this.onClose });
        Text('ПЕРИОД').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ bottom: 8 });
        Row() {
          ForEach(this.periods, (value: string) => {
            Text(value).fontSize(9).fontWeight(FontWeight.Bold)
              .fontColor(this.period === value ? DirectTheme.paper : DirectTheme.ink).fontFamily('monospace')
              .layoutWeight(1).height(40).textAlign(TextAlign.Center)
              .backgroundColor(this.period === value ? DirectTheme.ink : Color.Transparent)
              .border({ width: 1, color: this.period === value ? DirectTheme.ink : DirectTheme.line })
              .onClick(() => { this.period = value; DirectHaptics.selection(); });
          });
        }.width('100%');
        Column() {
          ForEach(this.plans, (plan: PlanCardData, index: number) => { this.planCard(plan, index); });
        }.width('100%').margin({ top: 16 });
        Row() {
          Column() {
            Text('НЕ НАШЛИ ПОДХОДЯЩИЙ?').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
            Text('Собрать свой тариф').fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 4 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Text('↗').fontSize(13).fontColor(DirectTheme.ink);
        }.width('100%').height(60).padding(13).border({ width: 1, color: DirectTheme.line })
          .onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.Constructor); });
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
            if (plan.badge.length > 0) Text(plan.badge).fontSize(6).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace')
              .backgroundColor(DirectTheme.acid).padding({ left: 6, right: 6, top: 5, bottom: 5 }).margin({ left: 7 });
          }
          Text(plan.subtitle).fontSize(9).fontColor(DirectTheme.muted).margin({ top: 4 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Column() {
          Text('—').fontSize(18).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace');
          Text(this.period).fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 2 });
        }.alignItems(HorizontalAlign.End);
      }.width('100%');
      Row() {
        this.fact('ТРАФИК', plan.traffic); this.fact('УСТРОЙСТВА', plan.devices); this.fact('ДНИ', this.periodDays());
      }.width('100%').padding({ top: 11, bottom: 11 }).border({ width: { top: 1 }, color: DirectTheme.line }).margin({ top: 11 });
      DirectNativeAction({ title: 'ВЫБРАТЬ', onTap: () => this.onFlow(DirectFlow.Payment) });
    }.width('100%').padding(14).border({ width: index === 1 ? 1.5 : 1, color: index === 1 ? DirectTheme.ink : DirectTheme.line }).margin({ bottom: 10 });
  }

  @Builder
  private fact(label: string, value: string) {
    Column() {
      Text(label).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
      Text(value).fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 4 });
    }.layoutWeight(1).alignItems(HorizontalAlign.Start);
  }

  private periodDays(): string {
    if (this.period === '3 месяца') return '90';
    if (this.period === '6 месяцев') return '180';
    if (this.period === '12 месяцев') return '365';
    return '30';
  }
}

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
        Slider({ value: this.days, min: 30, max: 360, step: 30 }).onChange((v: number) => this.days = Math.round(v / 30) * 30);
        this.control('УСТРОЙСТВА', String(this.devices));
        Slider({ value: this.devices, min: 1, max: 10, step: 1 }).onChange((v: number) => this.devices = Math.round(v));
        this.control('ТРАФИК', this.traffic + ' GB');
        Slider({ value: this.traffic, min: 50, max: 2000, step: 50 }).onChange((v: number) => this.traffic = Math.round(v / 50) * 50);
        Row() { Text('РАСЧЁТ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text('—').fontSize(20).fontColor(DirectTheme.ink).fontFamily('monospace'); }
          .width('100%').height(58).border({ width: { top: 1, bottom: 1 }, color: DirectTheme.line });
        DirectNativeAction({ title: 'ПРОДОЛЖИТЬ', onTap: () => this.onFlow(DirectFlow.Payment) });
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private control(label: string, value: string) {
    Row() { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text(value).fontSize(14).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace'); }
      .width('100%').height(42).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }
}

@Component
struct DirectPaymentNative {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    Column() {
      DirectNativeChrome({ kicker: 'DIRECT / OPERATION', title: 'Продолжение', subtitle: 'Платёжный адаптер Harmony подключается отдельно.', onClose: this.onClose });
      Column() {
        Text('ПЛАТЁЖНЫЙ ПРОЦЕСС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
        Text('Реальная транзакция пока не выполняется').fontSize(16).fontColor(DirectTheme.ink).margin({ top: 8 });
        Text('Экран намеренно не имитирует успешную оплату.').fontSize(11).fontColor(DirectTheme.muted).margin({ top: 6 });
      }.width('100%').padding(16).border({ width: 1, color: DirectTheme.line });
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
        DirectNativeChrome({ kicker: 'ACCOUNT / AUTH', title: this.title(), subtitle: 'Безопасный вход и синхронизация состояния.', onClose: this.onClose });
        if (this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.AuthEmail || this.flow === DirectFlow.AuthRegister || this.flow === DirectFlow.AuthRecovery) {
          this.field('EMAIL', 'email@example.com', InputType.Email);
        }
        if (this.flow === DirectFlow.AuthEmail) this.field('ПАРОЛЬ', 'Пароль', InputType.Password);
        if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) this.field('КОД', '000000', InputType.Number);
        if (this.flow === DirectFlow.AuthPhone) this.field('ТЕЛЕФОН', '+994 …', InputType.PhoneNumber);
        if (this.flow === DirectFlow.AuthBot) this.field('КОД БОТА', 'Код из Telegram-бота', InputType.Normal);
        DirectNativeAction({ title: this.actionTitle(), onTap: () => this.next() });
        if (this.flow === DirectFlow.AuthLogin) this.link('Войти по коду', () => this.onFlow(DirectFlow.AuthCode));
        if (this.flow === DirectFlow.AuthLogin) this.link('Войти по телефону', () => this.onFlow(DirectFlow.AuthPhone));
        if (this.flow === DirectFlow.AuthLogin) this.link('Войти кодом бота', () => this.onFlow(DirectFlow.AuthBot));
        if (this.flow === DirectFlow.AuthLogin) this.link('Создать аккаунт', () => this.onFlow(DirectFlow.AuthRegister));
        if (this.flow === DirectFlow.AuthLogin) this.link('Восстановить доступ', () => this.onFlow(DirectFlow.AuthRecovery));
      }.padding({ left: 20, right: 20, bottom: 30 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private field(label: string, placeholder: string, inputType: InputType) {
    Column() {
      Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ bottom: 7 });
      TextInput({ placeholder: placeholder }).type(inputType).height(50).width('100%').fontSize(14).fontColor(DirectTheme.ink)
        .backgroundColor('#73FFFFFF').border({ width: 1, color: DirectTheme.line }).padding({ left: 13, right: 13 }).margin({ bottom: 14 });
    }.width('100%');
  }

  @Builder private link(title: string, action: () => void) {
    Row() { Text(title).fontSize(11).fontColor(DirectTheme.ink); Blank(); Text('↗').fontSize(10).fontColor(DirectTheme.muted); }
      .width('100%').height(48).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); action(); });
  }

  private next() {
    if (this.flow === DirectFlow.AuthLogin) this.onFlow(DirectFlow.AuthEmail);
    else if (this.flow === DirectFlow.AuthEmail || this.flow === DirectFlow.AuthRegister || this.flow === DirectFlow.AuthRecovery) this.onFlow(DirectFlow.AuthCode);
    else if (this.flow === DirectFlow.AuthPhone) this.onFlow(DirectFlow.AuthPhoneCode);
    else if (this.flow === DirectFlow.AuthSuccess) this.onFlow(DirectFlow.Account);
    else this.onFlow(DirectFlow.AuthSuccess);
  }

  private title(): string {
    if (this.flow === DirectFlow.AuthRegister) return 'Регистрация';
    if (this.flow === DirectFlow.AuthRecovery) return 'Восстановление';
    if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) return 'Подтверждение';
    if (this.flow === DirectFlow.AuthPhone) return 'Телефон';
    if (this.flow === DirectFlow.AuthBot) return 'Код бота';
    if (this.flow === DirectFlow.AuthSuccess) return 'Готово';
    return this.flow === DirectFlow.AuthEmail ? 'Войти по email' : 'Войти';
  }

  private actionTitle(): string {
    if (this.flow === DirectFlow.AuthRegister) return 'СОЗДАТЬ АККАУНТ';
    if (this.flow === DirectFlow.AuthRecovery) return 'ПРОДОЛЖИТЬ';
    if (this.flow === DirectFlow.AuthPhone) return 'ПОЛУЧИТЬ КОД';
    if (this.flow === DirectFlow.AuthBot) return 'ПОДТВЕРДИТЬ';
    if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) return 'ПОДТВЕРДИТЬ';
    if (this.flow === DirectFlow.AuthSuccess) return 'К АККАУНТУ';
    return this.flow === DirectFlow.AuthLogin ? 'ПРОДОЛЖИТЬ' : 'ВОЙТИ';
  }
}

@Component
struct DirectSettingsNative {
  @Prop flow: DirectFlow = DirectFlow.Security;
  @Prop onClose: () => void = () => {};
  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({ kicker: 'PROFILE / SETTINGS', title: this.title(), subtitle: 'Настройки приложения и соединения.', onClose: this.onClose });
        this.row('01', 'Автоподключение', 'Настройки соединения');
        this.row('02', 'DNS', 'Защита DNS-запросов');
        this.row('03', 'Локальная сеть', 'Доступ к локальным устройствам');
        this.row('04', 'Диагностика', 'Состояние и журналы');
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private row(mark: string, title: string, subtitle: string) {
    Row() { Text(mark).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(42); Column() { Text(title).fontSize(13).fontColor(DirectTheme.ink); Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('›').fontSize(20).fontColor(DirectTheme.muted); }
      .width('100%').minHeight(64).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }

  private title(): string {
    if (this.flow === DirectFlow.Security) return 'Безопасность';
    if (this.flow === DirectFlow.Connection) return 'Соединение';
    if (this.flow === DirectFlow.Diagnostics) return 'Диагностика';
    if (this.flow === DirectFlow.Activity) return 'Активность';
    if (this.flow === DirectFlow.SystemSettings) return 'Системные настройки';
    if (this.flow === DirectFlow.ApplicationSettings) return 'Настройки приложения';
    if (this.flow === DirectFlow.CoreSettings) return 'Core';
    if (this.flow === DirectFlow.TunnelSettings) return 'Tunnel';
    if (this.flow === DirectFlow.OnDemandSettings) return 'On Demand';
    return 'Настройки';
  }
}

@Component
struct DirectNativeFallback {
  @Prop flow: DirectFlow = DirectFlow.None;
  @Prop onClose: () => void = () => {};
  build() {
    Column() {
      DirectNativeChrome({ kicker: 'DIRECT', title: 'Раздел', subtitle: 'Экран будет подключён к соответствующему сервису.', onClose: this.onClose });
    }.padding({ left: 20, right: 20 }).backgroundColor(DirectTheme.paper).width('100%').height('100%');
  }
}
