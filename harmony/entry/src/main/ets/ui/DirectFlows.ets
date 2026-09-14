import { DirectTheme } from './Theme';
import { DirectBalanceParityHost } from './DirectBalanceParity';
import { DirectBalanceTopUpParityV2 } from './DirectBalanceTopUpParityV2';
import { DirectPlanParityV3Host } from './DirectPlanParityV3';
import { DirectFullParityHost } from './DirectFullParity';
import { DirectNativeFlowHost } from './DirectNativeFlows';
import { DirectAuthParityV2 } from './DirectAuthParityV2';
import { DirectServerPickerParityV2 } from './DirectServerPickerParityV2';
import { DirectAccessParityV2 } from './DirectAccessParityV2';
import { DirectSubscriptionsParityV3 } from './DirectSubscriptionsParityV3';
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
    else if (this.flow >= DirectFlow.AuthLogin && this.flow <= DirectFlow.AuthSuccess) DirectAuthParityV2({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Payment) DirectNativeFlowHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow >= DirectFlow.Security && this.flow <= DirectFlow.OnDemandSettings) DirectFullParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.BalanceTopUp) DirectBalanceTopUpParityV2({ onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow === DirectFlow.Balance) DirectBalanceParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else if (this.flow !== DirectFlow.None) DirectFullParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    else Blank().backgroundColor(DirectTheme.paper);
  }
}
