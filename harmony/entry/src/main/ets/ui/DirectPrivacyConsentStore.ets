import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class DirectPrivacyConsentStore {
  private static readonly PREFS_NAME: string = 'vpndirect_privacy';
  private static readonly KEY_ACCEPTED: string = 'accepted';
  private static prefs: preferences.Preferences | null = null;
  private static acceptedCache: boolean = false;

  static init(context: common.UIAbilityContext): void {
    try {
      this.prefs = preferences.getPreferencesSync(context, { name: this.PREFS_NAME });
      this.acceptedCache = this.prefs.getSync(this.KEY_ACCEPTED, false) === true;
    } catch (err) {
      console.warn(`DirectPrivacyConsentStore init failed: ${err}`);
    }
  }

  static accepted(): boolean { return this.acceptedCache; }

  static accept(): void {
    this.acceptedCache = true;
    const prefs = this.prefs;
    if (prefs === null) return;
    try {
      prefs.putSync(this.KEY_ACCEPTED, true);
      prefs.flush().catch((err: Error) => console.warn(`privacy consent flush failed: ${err?.message ?? err}`));
    } catch (err) {
      console.warn(`privacy consent write failed: ${err}`);
    }
  }
}
