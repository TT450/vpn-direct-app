import { DirectTheme } from './Theme';
import { DirectBalanceParityHost } from './DirectBalanceParity';
import { DirectPlanParityV2Host } from './DirectPlanParityV2';
import { DirectFullParityHost } from './DirectFullParity';
import { DirectNativeFlowHost } from './DirectNativeFlows';
import { DirectServerPickerParityV2 } from './DirectServerPickerParityV2';
import { DirectAccessParityV2 } from './DirectAccessParityV2';
import { DirectSubscriptionsParityV2 } from './DirectSubscriptionsParityV2';
import { DirectFlow } from './DirectFlowModel';

export { DirectFlow } from './DirectFlowModel';

@Component
export struct DirectFlowHost {
  @Prop flow: DirectFlow = DirectFlow.None;
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  build() {
    if (this.flow === DirectFlow.ServerPicker) {
      DirectServerPickerParityV2({ onClose: this.onClose });
    } else if (this.flow === DirectFlow.Access) {
      DirectAccessParityV2({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Subscription) {
      DirectSubscriptionsParityV2({ onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Plans || this.flow === DirectFlow.Constructor) {
      DirectPlanParityV2Host({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Payment) {
      DirectNativeFlowHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if ((this.flow >= DirectFlow.AuthLogin && this.flow <= DirectFlow.AuthSuccess) ||
      (this.flow >= DirectFlow.Security && this.flow <= DirectFlow.OnDemandSettings)) {
      DirectNativeFlowHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow === DirectFlow.Balance || this.flow === DirectFlow.BalanceTopUp) {
      DirectBalanceParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else if (this.flow !== DirectFlow.None) {
      DirectFullParityHost({ flow: this.flow, onClose: this.onClose, onFlow: this.onFlow });
    } else {
      Blank().backgroundColor(DirectTheme.paper);
    }
  }
}
