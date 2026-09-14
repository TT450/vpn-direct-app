import { DirectTheme } from './Theme';
import { DirectBalanceParityHost } from './DirectBalanceParity';
import { DirectPlanParityHost } from './DirectPlanParity';
import { DirectFullParityHost } from './DirectFullParity';

export enum DirectFlow {
  None, ServerPicker, ConnectionReport, Profiles, Access,
  AuthLogin, AuthEmail, AuthCode, AuthRegister, AuthRecovery, AuthBot, AuthPhone, AuthPhoneCode, AuthSuccess,
  Plans, Constructor, Payment, PaymentProcessing, PaymentWaiting, PaymentCancelled, PaymentError, PaymentSuccess,
  Balance, BalanceTopUp, Management, Subscription, Security, Connection, Diagnostics, Activity, SystemSettings, About,
  ServiceLog, ApplicationSettings, CoreSettings, TunnelSettings, OnDemandSettings, ImportFile, ImportText, Legal, Privacy,
  Account, Devices, PaymentHistory
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
    } else if (this.flow !== DirectFlow.None) {
      DirectFullParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else {
      Blank().backgroundColor(DirectTheme.paper);
    }
  }
}
