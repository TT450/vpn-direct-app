import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectBalanceParityHost } from './DirectBalanceParity';
import { DirectPlanParityHost } from './DirectPlanParity';

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
    if (this.flow === DirectFlow.Plans || this.flow === DirectFlow.Constructor) {
      DirectPlanParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Balance || this.flow === DirectFlow.BalanceTopUp) {
      DirectBalanceParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.None) {
      Blank();
    } else if (this.flow === DirectFlow.ServerPicker) {
      DirectServerPickerFlow({ onClose: this.onClose });
    } else if (this.flow === DirectFlow.ConnectionReport) {
      DirectConnectionReportFlow({ onClose: this.onClose });
    } else if (this.flow === DirectFlow.Profiles) {
      DirectProfilesFlow({ onClose: this.onClose });
    } else if (this.flow === DirectFlow.Access) {
      DirectAccessFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.AuthEmail || this.flow === DirectFlow.AuthCode || this.flow === DirectFlow.AuthRegister || this.flow === DirectFlow.AuthRecovery || this.flow === DirectFlow.AuthBot || this.flow === DirectFlow.AuthPhone || this.flow === DirectFlow.AuthPhoneCode || this.flow === DirectFlow.AuthSuccess) {
      DirectAuthFlow({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Management || this.flow === DirectFlow.Subscription || this.flow === DirectFlow.Devices || this.flow === DirectFlow.PaymentHistory) {
      DirectManagementFlow({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Security || this.flow === DirectFlow.Connection || this.flow === DirectFlow.Diagnostics || this.flow === DirectFlow.Activity || this.flow === DirectFlow.SystemSettings || this.flow === DirectFlow.ApplicationSettings || this.flow === DirectFlow.CoreSettings || this.flow === DirectFlow.TunnelSettings || this.flow === DirectFlow.OnDemandSettings) {
      DirectSettingsFlow({ flow: this.flow, onClose: this.onClose });
    } else if (this.flow === DirectFlow.ImportFile || this.flow === DirectFlow.ImportText) {
      DirectImportFlow({ flow: this.flow, onClose: this.onClose });
    } else if (this.flow === DirectFlow.Legal || this.flow === DirectFlow.Privacy) {
      DirectLegalFlow({ flow: this.flow, onClose: this.onClose });
    } else if (this.flow === DirectFlow.Account) {
      DirectAccountFlow({ onClose: this.onClose, onFlow: this.onFlow });
    } else {
      DirectStateFlow({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    }
  }
}

@Component
struct DirectServerPickerFlow {
  @Prop onClose: () => void = () => {};
  build() { DirectSimplePage({ kicker: 'DIRECT / SERVER', title: 'Сервер', subtitle: 'Выберите доступную локацию.', onClose: this.onClose }); }
}

@Component
struct DirectConnectionReportFlow {
  @Prop onClose: () => void = () => {};
  build() { DirectSimplePage({ kicker: 'DIRECT / REPORT', title: 'Состояние соединения', subtitle: 'Телеметрия текущей VPN-сессии.', onClose: this.onClose }); }
}

@Component
struct DirectProfilesFlow {
  @Prop onClose: () => void = () => {};
  build() { DirectSimplePage({ kicker: 'DIRECT / PROFILES', title: 'Профили', subtitle: 'Сохранённые конфигурации подключения.', onClose: this.onClose }); }
}

@Component
struct DirectAccessFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() { DirectSimplePage({ kicker: 'DIRECT / ACCESS', title: 'Доступ', subtitle: 'Управление доступом к сервису.', onClose: this.onClose }); }
}

@Component
struct DirectAuthFlow {
  @Prop flow: DirectFlow = DirectFlow.AuthLogin;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() { DirectSimplePage({ kicker: 'ACCOUNT / AUTH', title: 'Аккаунт', subtitle: 'Вход и управление учётной записью.', onClose: this.onClose }); }
}

@Component
struct DirectManagementFlow {
  @Prop flow: DirectFlow = DirectFlow.Management;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() { DirectSimplePage({ kicker: 'DIRECT / MANAGEMENT', title: 'Управление', subtitle: 'Подписка, устройства и история операций.', onClose: this.onClose }); }
}

@Component
struct DirectSettingsFlow {
  @Prop flow: DirectFlow = DirectFlow.Security;
  @Prop onClose: () => void = () => {};
  build() { DirectSimplePage({ kicker: 'DIRECT / SETTINGS', title: 'Настройки', subtitle: 'Параметры подключения и приложения.', onClose: this.onClose }); }
}

@Component
struct DirectImportFlow {
  @Prop flow: DirectFlow = DirectFlow.ImportFile;
  @Prop onClose: () => void = () => {};
  build() { DirectSimplePage({ kicker: 'DIRECT / IMPORT', title: 'Импорт', subtitle: 'Добавление конфигурации подключения.', onClose: this.onClose }); }
}

@Component
struct DirectLegalFlow {
  @Prop flow: DirectFlow = DirectFlow.Legal;
  @Prop onClose: () => void = () => {};
  build() { DirectSimplePage({ kicker: 'DIRECT / LEGAL', title: this.flow === DirectFlow.Privacy ? 'Конфиденциальность' : 'Правовая информация', subtitle: 'Документы и сведения о приложении.', onClose: this.onClose }); }
}

@Component
struct DirectAccountFlow {
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() { DirectSimplePage({ kicker: 'ACCOUNT', title: 'Аккаунт', subtitle: 'Профиль и состояние учётной записи.', onClose: this.onClose }); }
}

@Component
struct DirectStateFlow {
  @Prop flow: DirectFlow = DirectFlow.PaymentProcessing;
  @Prop onClose: () => void = () => {};
  @Prop onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() { DirectSimplePage({ kicker: 'DIRECT / STATE', title: 'Состояние', subtitle: 'Операция выполняется или ожидает результата.', onClose: this.onClose }); }
}

@Component
struct DirectSimplePage {
  @Prop kicker: string = '';
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop onClose: () => void = () => {};
  build() {
    Column() {
      Row() { Button('←').fontSize(18).fontColor(DirectTheme.muted).backgroundColor(Color.Transparent).width(36).height(36).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); Column() { Text(this.kicker).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(this.title).fontSize(22).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 6 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); }.width('100%').height(54);
      Text(this.subtitle).fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ bottom: 18 });
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 24 }).backgroundColor(DirectTheme.paper);
  }
}
