import { DirectTheme } from './Theme';
import { DirectBalanceParityHost } from './DirectBalanceParity';
import { DirectPlanParityHost } from './DirectPlanParity';
import { DirectFullParityHost } from './DirectFullParity';
import { DirectFlow } from './DirectFlowModel';

export { DirectFlow } from './DirectFlowModel';

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
