import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class DirectPrivacyConsentStore {
  private static readonly NAME: string = 'vpndirect_privacy';
  private static readonly KEY: string = 'privacy_disclosure_accepted';
  private static prefs: preferences.Preferences | null = null;
  private static acceptedValue: boolean = false;

  static init(context: common.UIAbilityContext): void {
    try {
      DirectPrivacyConsentStore.prefs = preferences.getPreferencesSync(context, { name: DirectPrivacyConsentStore.NAME });
      const value = DirectPrivacyConsentStore.prefs.getSync(DirectPrivacyConsentStore.KEY, false);
      DirectPrivacyConsentStore.acceptedValue = value === true;
    } catch (err) {
      DirectPrivacyConsentStore.prefs = null;
      DirectPrivacyConsentStore.acceptedValue = false;
      console.warn(`VPN Direct: privacy consent store init failed: ${err}`);
    }
  }

  static accepted(): boolean { return DirectPrivacyConsentStore.acceptedValue; }

  static accept(): void {
    DirectPrivacyConsentStore.acceptedValue = true;
    const prefs = DirectPrivacyConsentStore.prefs;
    if (prefs === null) return;
    try {
      prefs.putSync(DirectPrivacyConsentStore.KEY, true);
      prefs.flush().catch((err: Error) => console.warn(`VPN Direct: privacy consent flush failed: ${err?.message ?? err}`));
    } catch (err) {
      console.warn(`VPN Direct: privacy consent save failed: ${err}`);
    }
  }
}
