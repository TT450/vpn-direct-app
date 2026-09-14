import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export interface VpnRuntimeState {
  state: string;
  message?: string;
  at?: number;
}

export class VpnStateStore {
  static path(context: common.UIAbilityContext): string {
    return `${context.filesDir}/vpn-state.json`;
  }

  static read(context: common.UIAbilityContext): VpnRuntimeState | null {
    try {
      const raw: string = fileIo.readTextSync(VpnStateStore.path(context));
      if (raw.length === 0) return null;
      return JSON.parse(raw) as VpnRuntimeState;
    } catch (error) {
      return null;
    }
  }
}
