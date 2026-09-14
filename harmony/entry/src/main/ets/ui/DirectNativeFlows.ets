import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { DirectBackendRuntime, DirectCheckoutQuoteRequest } from '../backend/DirectBackendRuntime';

@Component
export struct DirectNativeFlowHost {
  @Prop flow: DirectFlow = DirectFlow.None;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

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
  onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent)
          .width(36).height(36)
          .onClick(() => { DirectHaptics.navigation(); this.onClose(); });
        Column() {
          Text(this.kicker).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Text(this.title)
            .fontSize(DirectTypography.pageTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .margin({ top: 6 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      }.width('100%').height(54);
      Text(this.subtitle).fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 18 });
    }.width('100%');
  }
}

@Component
struct DirectNativeAction {
  @Prop title: string = '';
  onTap: () => void = () => {};

  build() {
    Row() {
      Text(this.title).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace');
      Blank();
      Text('→').fontSize(12).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid);
    }.width('100%').height(DirectTheme.authPrimaryHeight).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink)
      .onClick(() => { DirectHaptics.selection(); this.onTap(); });
  }
}

interface PlanCardData { name: string; traffic: string; devices: string; subtitle: string; badge: string; }

@Component
struct DirectPlansNative {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
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
      DirectNativeAction({ title: 'КУПИТЬ', onTap: () => this.onFlow(DirectFlow.Payment) });
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
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
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

// ---------------------------------------------------------------------------
// DirectPaymentNative
// Reads constructor / plan params from AppStorage (set by Constructor КУПИТЬ).
// Shows amount hero + Balance / External method selector + action.
// Wires quoteCheckout if available, else shows amount from AppStorage.
// ---------------------------------------------------------------------------
@Component
struct DirectPaymentNative {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

  // Constructor params written by DirectConstructorParity.purchaseConstructor()
  @StorageProp('constructor_days') private constructorDays: number = 30;
  @StorageProp('constructor_devices') private constructorDevices: number = 1;
  @StorageProp('constructor_traffic_gb') private constructorTrafficGb: number = 100;
  @StorageProp('constructor_price') private constructorPrice: string = '—';
  // Plan params written by DirectPlansParity planCard КУПИТЬ (optional)
  @StorageProp('pending_plan_name') private pendingPlanName: string = '';
  @StorageProp('pending_plan_price') private pendingPlanPrice: string = '—';

  @State private method: string = 'balance'; // 'balance' | 'external'
  @State private liveAmount: string = '—';
  @State private liveTitle: string = '';
  @State private quoting: boolean = false;
  @State private errorText: string = '';
  @State private busy: boolean = false;

  aboutToAppear(): void {
    this.liveAmount = this.constructorPrice !== '—' && this.constructorPrice.length > 0
      ? this.constructorPrice
      : (this.pendingPlanPrice !== '—' && this.pendingPlanPrice.length > 0 ? this.pendingPlanPrice : '—');
    this.liveTitle = this.pendingPlanName.length > 0
      ? this.pendingPlanName
      : `${this.constructorDays} дн · ${this.constructorDevices} устр · ${this.trafficLabel()}`;
    void this.fetchQuote();
  }

  private trafficLabel(): string {
    const gb = this.constructorTrafficGb;
    if (gb <= 0) {
      return '∞';
    }
    if (gb >= 1000) {
      return `${Math.round(gb / 1000)} TB`;
    }
    return `${gb} GB`;
  }

  private async fetchQuote(): Promise<void> {
    const quote = DirectBackendRuntime.quoteCheckout;
    if (!quote) {
      return;
    }
    this.quoting = true;
    try {
      const req: DirectCheckoutQuoteRequest = {
        productKind: 'constructor',
        days: this.constructorDays,
        devices: this.constructorDevices,
        trafficGb: this.constructorTrafficGb === 0 ? -1 : this.constructorTrafficGb
      };
      const result = await quote(req);
      if (result.error && result.error.length > 0) {
        // keep AppStorage price
      } else if (result.amount !== undefined) {
        const cur = result.currency ?? '₽';
        this.liveAmount = `${result.amount} ${cur}`;
      }
      if (result.planName && result.planName.length > 0) {
        this.liveTitle = result.planName;
      }
    } catch {
      // keep existing
    } finally {
      this.quoting = false;
    }
  }

  private async proceed(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.errorText = '';
    this.busy = true;
    try {
      // If checkoutStatus hook is wired, initiate and poll; else surface clear error.
      const checkStatus = DirectBackendRuntime.checkoutStatus;
      if (!checkStatus) {
        // No payment adapter connected yet — surface Russian error per spec
        this.errorText = 'Платёжный адаптер не подключён. Оплата через внешний шлюз доступна после подтверждения тарифа.';
        this.busy = false;
        return;
      }
      // payment_id may come from a future initCheckout hook; for now navigate to waiting
      this.onFlow(DirectFlow.PaymentWaiting);
    } catch (err) {
      const msg = err instanceof Error ? err.message : `${err}`;
      this.errorText = msg.length > 0 ? msg : 'Не удалось выполнить платёж';
      this.busy = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({
          kicker: 'DIRECT / ОПЛАТА',
          title: 'Оплата',
          subtitle: 'Выберите способ и подтвердите.',
          onClose: this.onClose
        });

        // Amount hero
        Column() {
          Text('К ОПЛАТЕ')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor('#6BFFFFFF')
            .fontFamily('monospace');
          Text(this.quoting ? '…' : this.liveAmount)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .fontFamily('monospace')
            .margin({ top: 8 });
          Text(this.liveTitle)
            .fontSize(10)
            .fontColor('#80FFFFFF')
            .margin({ top: 6 });
        }
          .width('100%')
          .padding(18)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(DirectTheme.ink)
          .margin({ bottom: 20 });

        // Method selector
        Text('СПОСОБ ОПЛАТЫ')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.muted)
          .fontFamily('monospace')
          .width('100%')
          .margin({ bottom: 8 });

        this.methodRow('balance', 'Баланс Direct',
          'Мгновенно · средства с внутреннего счёта');
        this.methodRow('external', 'Внешняя оплата',
          'Банковская карта / СБП / другой способ');

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(11)
            .fontColor('#CC0000')
            .width('100%')
            .padding(12)
            .border({ width: 1, color: DirectTheme.line })
            .margin({ top: 14, bottom: 8 });
        }

        // Action
        Row() {
          Text(this.busy ? '…' : 'ОПЛАТИТЬ')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace');
          Blank();
          Text('→').fontSize(12).fontColor(DirectTheme.acid);
        }
          .width('100%')
          .height(DirectTheme.authPrimaryHeight)
          .padding({ left: 14, right: 14 })
          .backgroundColor(DirectTheme.ink)
          .margin({ top: 16 })
          .onClick(() => { void this.proceed(); });

        Blank().height(28);
      }.padding({ left: 20, right: 20, top: 4 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private methodRow(id: string, title: string, subtitle: string) {
    Row() {
      Text(this.method === id ? '◆' : '○')
        .fontSize(14)
        .fontColor(this.method === id ? DirectTheme.green : DirectTheme.ink)
        .width(22)
        .textAlign(TextAlign.Center);
      Column() {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.ink);
        Text(subtitle)
          .fontSize(9.5)
          .fontColor(DirectTheme.muted)
          .margin({ top: 3 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 });
    }
      .width('100%')
      .constraintSize({ minHeight: 58 })
      .border({ width: { bottom: 1 }, color: DirectTheme.line })
      .onClick(() => {
        this.method = id;
        DirectHaptics.selection();
      });
  }
}

@Component
struct DirectAuthNative {
  @Prop flow: DirectFlow = DirectFlow.AuthLogin;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State email: string = '';
  @State password: string = '';
  @State name: string = '';
  @State code: string = '';
  @State confirmation: string = '';
  @State errorText: string = '';
  @State busy: boolean = false;
  @State infoText: string = '';

  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({
          kicker: 'ACCOUNT / AUTH',
          title: this.title(),
          subtitle: 'Безопасный вход и синхронизация состояния.',
          onClose: this.onClose
        });
        Row() {
          Text('DIRECT')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace')
            .width(DirectTheme.authBrandW)
            .height(DirectTheme.authBrandH)
            .textAlign(TextAlign.Center)
            .backgroundColor(DirectTheme.ink);
          Column() {
            Text('БЕЗОПАСНЫЙ ВХОД')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
            Text('Продолжайте с выбранным способом')
              .fontSize(10)
              .fontColor(DirectTheme.muted)
              .margin({ top: 3 });
          }.alignItems(HorizontalAlign.Start).margin({ left: 12 });
          Blank();
        }.width('100%').margin({ bottom: 20 });
        if (this.errorText.length > 0) {
          Text(this.errorText).fontSize(12).fontColor('#B00020').width('100%')
            .padding(10).border({ width: 1, color: DirectTheme.line }).margin({ bottom: 12 });
        }
        if (this.infoText.length > 0) {
          Text(this.infoText).fontSize(12).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 12 });
        }
        if (this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.AuthEmail ||
          this.flow === DirectFlow.AuthRegister || this.flow === DirectFlow.AuthRecovery ||
          this.flow === DirectFlow.AuthCode) {
          this.boundField('EMAIL', 'email@example.com', InputType.Email, this.email, (v: string) => {
            this.email = v;
          });
        }
        if (this.flow === DirectFlow.AuthRegister) {
          this.boundField('ИМЯ', 'Имя', InputType.Normal, this.name, (v: string) => {
            this.name = v;
          });
        }
        if (this.flow === DirectFlow.AuthEmail || this.flow === DirectFlow.AuthRegister) {
          this.boundField('ПАРОЛЬ', 'Пароль', InputType.Password, this.password, (v: string) => {
            this.password = v;
          });
        }
        if (this.flow === DirectFlow.AuthRegister) {
          this.boundField('ПОВТОР ПАРОЛЯ', 'Пароль ещё раз', InputType.Password, this.confirmation, (v: string) => {
            this.confirmation = v;
          });
        }
        if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) {
          this.boundField('КОД', '000000', InputType.Number, this.code, (v: string) => {
            this.code = v;
          });
        }
        if (this.flow === DirectFlow.AuthPhone) {
          this.boundField('ТЕЛЕФОН', '+994 …', InputType.PhoneNumber, this.email, (v: string) => {
            this.email = v;
          });
        }
        if (this.flow === DirectFlow.AuthBot) {
          this.boundField('КОД БОТА', 'Код из Telegram-бота', InputType.Normal, this.code, (v: string) => {
            this.code = v;
          });
        }
        DirectNativeAction({
          title: this.busy ? '…' : this.actionTitle(),
          onTap: () => {
            void this.next();
          }
        });
        if (this.flow === DirectFlow.AuthLogin) {
          this.link('Войти по коду', () => this.onFlow(DirectFlow.AuthCode));
        }
        if (this.flow === DirectFlow.AuthLogin) {
          this.link('Войти по телефону', () => this.onFlow(DirectFlow.AuthPhone));
        }
        if (this.flow === DirectFlow.AuthLogin) {
          this.link('Войти кодом бота', () => this.onFlow(DirectFlow.AuthBot));
        }
        if (this.flow === DirectFlow.AuthLogin) {
          this.link('Создать аккаунт', () => this.onFlow(DirectFlow.AuthRegister));
        }
        if (this.flow === DirectFlow.AuthLogin) {
          this.link('Восстановить доступ', () => this.onFlow(DirectFlow.AuthRecovery));
        }
      }.padding({ left: 20, right: 20, bottom: 30 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private boundField(label: string, placeholder: string, inputType: InputType, value: string, onChange: (v: string) => void) {
    Column() {
      Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width('100%').margin({ bottom: 7 });
      TextInput({ placeholder: placeholder, text: value })
        .type(inputType)
        .height(50)
        .width('100%')
        .fontSize(14)
        .fontColor(DirectTheme.ink)
        .backgroundColor(DirectTheme.fieldFill)
        .border({ width: 1, color: DirectTheme.line })
        .padding({ left: 13, right: 13 })
        .margin({ bottom: 14 })
        .onChange((v: string) => onChange(v));
    }.width('100%');
  }

  @Builder
  private link(title: string, action: () => void) {
    Row() {
      Text(title).fontSize(11).fontColor(DirectTheme.ink);
      Blank();
      Text('↗').fontSize(10).fontColor(DirectTheme.muted);
    }.width('100%').height(48).border({ width: { bottom: 1 }, color: DirectTheme.line })
      .onClick(() => {
        DirectHaptics.selection();
        action();
      });
  }

  private failClosed(message: string): void {
    this.errorText = message;
    this.busy = false;
  }

  private async next(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.errorText = '';
    this.infoText = '';
    if (this.flow === DirectFlow.AuthLogin) {
      this.onFlow(DirectFlow.AuthEmail);
      return;
    }
    if (this.flow === DirectFlow.AuthSuccess) {
      this.onFlow(DirectFlow.Account);
      return;
    }
    if (this.flow === DirectFlow.AuthPhone) {
      this.onFlow(DirectFlow.AuthPhoneCode);
      return;
    }
    if (this.flow === DirectFlow.AuthPhoneCode || this.flow === DirectFlow.AuthBot) {
      this.failClosed('Этот способ входа пока не подключён');
      return;
    }

    this.busy = true;
    try {
      if (this.flow === DirectFlow.AuthEmail) {
        const login = DirectBackendRuntime.loginWithPassword;
        if (!login) {
          this.failClosed('Сервис входа недоступен');
          return;
        }
        await login(this.email.trim(), this.password);
        this.onFlow(DirectFlow.AuthSuccess);
        return;
      }
      if (this.flow === DirectFlow.AuthRegister) {
        const register = DirectBackendRuntime.registerWithPassword;
        if (!register) {
          this.failClosed('Сервис регистрации недоступен');
          return;
        }
        const displayName = this.name.trim().length > 0 ? this.name.trim() : this.email.trim().split('@')[0];
        await register(displayName, this.email.trim(), this.password, this.confirmation);
        this.onFlow(DirectFlow.AuthSuccess);
        return;
      }
      if (this.flow === DirectFlow.AuthRecovery) {
        const reset = DirectBackendRuntime.requestPasswordReset;
        if (!reset) {
          this.failClosed('Восстановление недоступно');
          return;
        }
        await reset(this.email.trim());
        this.infoText = 'Если аккаунт существует, инструкции отправлены на email';
        return;
      }
      if (this.flow === DirectFlow.AuthCode) {
        const trimmedEmail = this.email.trim();
        const trimmedCode = this.code.trim();
        if (trimmedCode.length === 0) {
          const send = DirectBackendRuntime.sendEmailCode;
          if (!send) {
            this.failClosed('Отправка кода недоступна');
            return;
          }
          await send(trimmedEmail);
          this.infoText = 'Код отправлен на email';
          return;
        }
        const verify = DirectBackendRuntime.verifyEmailCode;
        if (!verify) {
          this.failClosed('Проверка кода недоступна');
          return;
        }
        await verify(trimmedEmail, trimmedCode);
        this.onFlow(DirectFlow.AuthSuccess);
        return;
      }
      this.onFlow(DirectFlow.AuthSuccess);
    } catch (err) {
      const message = err instanceof Error ? err.message : `${err}`;
      this.errorText = message.length > 0 ? message : 'Не удалось выполнить вход';
    } finally {
      this.busy = false;
    }
  }

  private title(): string {
    if (this.flow === DirectFlow.AuthRegister) {
      return 'Регистрация';
    }
    if (this.flow === DirectFlow.AuthRecovery) {
      return 'Восстановление';
    }
    if (this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthPhoneCode) {
      return 'Подтверждение';
    }
    if (this.flow === DirectFlow.AuthPhone) {
      return 'Телефон';
    }
    if (this.flow === DirectFlow.AuthBot) {
      return 'Код бота';
    }
    if (this.flow === DirectFlow.AuthSuccess) {
      return 'Готово';
    }
    return this.flow === DirectFlow.AuthEmail ? 'Войти по email' : 'Войти';
  }

  private actionTitle(): string {
    if (this.flow === DirectFlow.AuthRegister) {
      return 'СОЗДАТЬ АККАУНТ';
    }
    if (this.flow === DirectFlow.AuthRecovery) {
      return 'ПРОДОЛЖИТЬ';
    }
    if (this.flow === DirectFlow.AuthPhone) {
      return 'ПОЛУЧИТЬ КОД';
    }
    if (this.flow === DirectFlow.AuthBot) {
      return 'ПОДТВЕРДИТЬ';
    }
    if (this.flow === DirectFlow.AuthCode) {
      return this.code.trim().length === 0 ? 'ПОЛУЧИТЬ КОД' : 'ПОДТВЕРДИТЬ';
    }
    if (this.flow === DirectFlow.AuthPhoneCode) {
      return 'ПОДТВЕРДИТЬ';
    }
    if (this.flow === DirectFlow.AuthSuccess) {
      return 'К АККАУНТУ';
    }
    return this.flow === DirectFlow.AuthLogin ? 'ПРОДОЛЖИТЬ' : 'ВОЙТИ';
  }
}

// ---------------------------------------------------------------------------
// DirectSettingsNative — Security / Connection with real persisted toggles.
// AppStorage keys mirror iOS UserDefaults booleans via StorageProp.
// ---------------------------------------------------------------------------
@Component
struct DirectSettingsNative {
  @Prop flow: DirectFlow = DirectFlow.Security;
  onClose: () => void = () => {};

  // Persisted preference toggles — mirroring iOS DirectSecurityCenterView / DirectConnectionSettingsView
  @StorageProp('pref_auto_connect') private autoConnect: boolean = false;
  @StorageProp('pref_dns_protect') private dnsProtect: boolean = true;
  @StorageProp('pref_face_id') private faceID: boolean = false;
  @StorageProp('pref_lan_access') private lanAccess: boolean = false;
  @StorageProp('pref_ipv6') private ipv6: boolean = false;

  build() {
    Scroll() {
      Column() {
        DirectNativeChrome({
          kicker: 'PROFILE / SETTINGS',
          title: this.title(),
          subtitle: 'Настройки приложения и соединения.',
          onClose: this.onClose
        });

        if (this.flow === DirectFlow.Security || this.flow === DirectFlow.ApplicationSettings) {
          this.sectionHeader('01', 'БЕЗОПАСНОСТЬ', '03');
          this.toggleRow('Автоподключение', 'Подключаться при запуске приложения',
            this.autoConnect, 'pref_auto_connect');
          this.toggleRow('Face ID / отпечаток', 'Биометрическая защита входа (заглушка)',
            this.faceID, 'pref_face_id');
          this.toggleRow('Защита DNS', 'Все DNS-запросы через зашифрованный туннель',
            this.dnsProtect, 'pref_dns_protect');
        }

        if (this.flow === DirectFlow.Connection || this.flow === DirectFlow.CoreSettings) {
          this.sectionHeader('01', 'СОЕДИНЕНИЕ', '02');
          this.toggleRow('Доступ к локальной сети', 'Устройства в LAN видны при активном VPN',
            this.lanAccess, 'pref_lan_access');
          this.toggleRow('IPv6', 'Туннелирование IPv6-трафика',
            this.ipv6, 'pref_ipv6');
        }

        if (this.flow === DirectFlow.Diagnostics || this.flow === DirectFlow.Activity) {
          this.sectionHeader('01', 'ДИАГНОСТИКА', '02');
          this.infoRow('Журнал событий', 'Доступен в разделе «Активность»', true);
          this.infoRow('Статус VPN', 'Состояние текущего соединения', false);
        }

        if (this.flow === DirectFlow.SystemSettings) {
          this.sectionHeader('01', 'ОСНОВНОЕ', '04');
          this.infoRow('Статус', 'Текущее состояние VPN Direct', false);
          this.infoRow('Системные разрешения', 'Параметры HarmonyOS', false);
          this.sectionHeader('02', 'СЕТЬ', '02');
          this.infoRow('Диагностика', 'Сведения для проверки соединения', true);
          this.infoRow('О приложении', 'VPN Direct · HarmonyOS', false);
        }

        if (this.flow === DirectFlow.TunnelSettings) {
          this.sectionHeader('01', 'ТУННЕЛЬ', '02');
          this.infoRow('Протокол', 'VLESS · REALITY', true);
          this.infoRow('Маршрутизация', 'Direct auto-route', false);
        }

        if (this.flow === DirectFlow.OnDemandSettings) {
          this.sectionHeader('01', 'ON-DEMAND', '01');
          this.toggleRow('Автоподключение по требованию', 'Активируется по правилам сети',
            this.autoConnect, 'pref_auto_connect');
        }

        Blank().height(28);
      }.padding({ left: 20, right: 20 });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private sectionHeader(number: string, title: string, meta: string) {
    Row() {
      Text(number).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
      Text(title).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ left: 11 });
      Blank();
      Text(meta).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
    }
      .width('100%')
      .height(DirectTheme.systemSectionHeight)
      .border({ width: { top: 1 }, color: DirectTheme.ink });
  }

  /** storageKey written directly from Toggle.onChange — no lambda double-flip. */
  @Builder
  private toggleRow(title: string, subtitle: string, value: boolean, storageKey: string) {
    Row() {
      Column() {
        Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
        Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Toggle({ type: ToggleType.Switch, isOn: value })
        .width(44)
        .height(26)
        .selectedColor(DirectTheme.green)
        .onChange((on: boolean) => {
          AppStorage.setOrCreate(storageKey, on);
          DirectHaptics.selection();
        });
    }
      .width('100%')
      .constraintSize({ minHeight: DirectTheme.systemRowMin })
      .border({ width: { bottom: 1 }, color: DirectTheme.line });
  }

  @Builder
  private infoRow(title: string, subtitle: string, accent: boolean) {
    Row() {
      Text(accent ? '◆' : '○')
        .fontSize(14)
        .fontColor(accent ? DirectTheme.green : DirectTheme.ink)
        .width(25)
        .textAlign(TextAlign.Center);
      Column() {
        Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
        Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 13 });
      Text('↗').fontSize(10).fontColor(accent ? DirectTheme.green : DirectTheme.muted);
    }
      .width('100%')
      .constraintSize({ minHeight: DirectTheme.systemRowMin })
      .border({ width: { bottom: 1 }, color: DirectTheme.line });
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
  onClose: () => void = () => {};
  build() {
    Column() {
      DirectNativeChrome({ kicker: 'DIRECT', title: 'Раздел', subtitle: 'Экран будет подключён к соответствующему сервису.', onClose: this.onClose });
    }.padding({ left: 20, right: 20 }).backgroundColor(DirectTheme.paper).width('100%').height('100%');
  }
}
