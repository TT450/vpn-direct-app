import { DirectTheme } from './Theme';
import { DirectBalanceParityHost } from './DirectBalanceParity';
import { DirectPlanParityHost } from './DirectPlanParity';
import { DirectFullParityHost } from './DirectFullParity';
import { DirectServerPickerParityV2 } from './DirectServerPickerParityV2';
import { DirectAccessParityV2 } from './DirectAccessParityV2';
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
    } else if (this.flow === DirectFlow.Plans || this.flow === DirectFlow.Constructor) {
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
