import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ensureLocalBackendRegistered } from '../backend/DirectBackendLocal';
import { DirectBackendRuntime } from '../backend/DirectBackendRuntime';
import { DirectSessionStore } from '../model/DirectSessionStore';
import { ImportedSubscriptionStore } from '../vpn/ImportedSubscriptionStore';

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    ensureLocalBackendRegistered();
    DirectBackendRuntime.warmUp(this.context);

    // Init session AppStorage keys synchronously before any page renders.
    DirectSessionStore.init();

    // Init imported subscription Preferences store.
    ImportedSubscriptionStore.init(this.context);
    // Restore any previously imported subscription as the active VPN provider.
    ImportedSubscriptionStore.wireProvider();

    // Kick off async session refresh (auth + locations). Non-blocking.
    DirectSessionStore.refresh().catch((err: Error) => {
      console.warn(`VPN Direct: session refresh failed: ${err?.message ?? err}`);
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    ensureLocalBackendRegistered();
    DirectBackendRuntime.warmUp(this.context);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        console.error(`VPN Direct: failed to load main page: ${JSON.stringify(err)}`);
        return;
      }
      console.info('VPN Direct: main page loaded');
    });
  }

  onWindowStageDestroy(): void {}
  onForeground(): void {}
  onBackground(): void {}
}
