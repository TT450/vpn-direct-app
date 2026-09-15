import { DirectTheme } from './Theme';
import { DirectBalanceParityHost } from './DirectBalanceParity';
import { DirectBalanceTopUpParityV2 } from './DirectBalanceTopUpParityV2';
import { DirectPlanParityV3Host } from './DirectPlanParityV3';
import { DirectFullParityHost } from './DirectFullParity';
import { DirectAuthParityV4 } from './DirectAuthParityV4';
import { DirectAccountParityV2 } from './DirectAccountParityV2';
import { DirectServerPickerParityV2 } from './DirectServerPickerParityV2';
import { DirectAccessParityV2 } from './DirectAccessParityV2';
import { DirectSubscriptionsParityV3 } from './DirectSubscriptionsParityV3';
import { DirectAdvancedParityV2 } from './DirectAdvancedParityV2';
import { DirectPaymentParityV2 } from './DirectPaymentParityV2';
import { DirectLegalAboutParityV2 } from './DirectLegalAboutParityV2';
import { DirectSystemParityV2 } from './DirectSystemParityV2';
import { DirectOnDemandParityV2 } from './DirectOnDemandParityV2';
import { DirectAccountUtilityParityV2 } from './DirectAccountUtilityParityV2';
import { DirectFlow } from './DirectFlowModel';
export { DirectFlow } from './DirectFlowModel';

@Component
export struct DirectFlowHost {
  @Prop flow: DirectFlow = DirectFlow.None;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    if (this.flow === DirectFlow.ServerPicker) DirectServerPickerParityV2({ onClose: this.onClose });
    else if (this.flow === DirectFlow.Access) DirectAccessParityV2({ onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Subscription) DirectSubscriptionsParityV3({ onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Plans || this.flow === DirectFlow.Constructor) DirectPlanParityV3Host({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Account) DirectAccountParityV2({ onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow >= DirectFlow.AuthLogin && this.flow <= DirectFlow.AuthSuccess) DirectAuthParityV4({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Payment) DirectPaymentParityV2({ onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.SystemSettings) DirectSystemParityV2({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.OnDemandSettings) DirectOnDemandParityV2({ onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow >= DirectFlow.Security && this.flow < DirectFlow.SystemSettings) DirectAdvancedParityV2({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.BalanceTopUp) DirectBalanceTopUpParityV2({ onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Balance) DirectBalanceParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Legal || this.flow === DirectFlow.Privacy || this.flow === DirectFlow.About) DirectLegalAboutParityV2({ flow: this.flow, onClose: this.onClose });
    else if (this.flow === DirectFlow.Devices || this.flow === DirectFlow.PaymentHistory || this.flow === DirectFlow.AuthLogin || this.flow === DirectFlow.Account) DirectAccountUtilityParityV2({ flow: this.flow, onClose: this.onClose });
    else if (this.flow !== DirectFlow.None) DirectFullParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else Blank().backgroundColor(DirectTheme.paper);
  }
}
