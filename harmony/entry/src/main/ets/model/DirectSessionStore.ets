import { DirectBackendRuntime, DirectMe, DirectLocationRecord } from '../backend/DirectBackendRuntime';
import { ImportedSubscriptionStore, ImportedSubscription } from '../vpn/ImportedSubscriptionStore';

/** AppStorage keys — use with @StorageProp / @StorageLink in components. */
export const SESSION_HAS_PREMIUM: string = 'session_has_premium';
export const SESSION_DISPLAY_NAME: string = 'session_display_name';
export const SESSION_REMAINING_DAYS: string = 'session_remaining_days';
export const SESSION_BALANCE_CENTS: string = 'session_balance_cents';
export const SESSION_LOADED: string = 'session_loaded';
export const SESSION_ERROR: string = 'session_error';
export const SESSION_LOCATIONS_JSON: string = 'session_locations_json';

/**
 * Singleton session state store backed by AppStorage.
 * Pages use @StorageProp(SESSION_*) to react to changes automatically.
 */
export class DirectSessionStore {
  /** Call once at startup (e.g. EntryAbility.onCreate) before refresh(). */
  static init(): void {
    AppStorage.setOrCreate<boolean>(SESSION_HAS_PREMIUM, false);
    AppStorage.setOrCreate<string>(SESSION_DISPLAY_NAME, '');
    AppStorage.setOrCreate<number>(SESSION_REMAINING_DAYS, 0);
    AppStorage.setOrCreate<number>(SESSION_BALANCE_CENTS, 0);
    AppStorage.setOrCreate<boolean>(SESSION_LOADED, false);
    AppStorage.setOrCreate<string>(SESSION_ERROR, '');
    AppStorage.setOrCreate<string>(SESSION_LOCATIONS_JSON, '[]');
  }

  /** Fetches session data from the backend and stores it in AppStorage. */
  static async refresh(): Promise<void> {
    AppStorage.set<boolean>(SESSION_LOADED, false);
    AppStorage.set<string>(SESSION_ERROR, '');
    try {
      const bootstrap = DirectBackendRuntime.bootstrapSession;
      if (bootstrap !== null && bootstrap !== undefined) {
        await bootstrap();
      }
      const fetchMe = DirectBackendRuntime.fetchMe;
      if (fetchMe !== null && fetchMe !== undefined) {
        const me: DirectMe = await fetchMe();
        DirectSessionStore.applyMe(me);
        // Wire subscription URL from backend profile so VPN can connect
        await DirectSessionStore.applySubscriptionUrl(me);
      }
      const locations: DirectLocationRecord[] = await DirectBackendRuntime.fetchLocations();
      AppStorage.set<string>(SESSION_LOCATIONS_JSON, JSON.stringify(locations));
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : `${err}`;
      AppStorage.set<string>(SESSION_ERROR, msg.length > 0 ? msg : 'Не удалось загрузить данные');
    } finally {
      AppStorage.set<boolean>(SESSION_LOADED, true);
    }
  }

  static hasPremium(): boolean {
    return AppStorage.get<boolean>(SESSION_HAS_PREMIUM) ?? false;
  }

  static displayName(): string {
    return AppStorage.get<string>(SESSION_DISPLAY_NAME) ?? '';
  }

  static remainingDays(): number {
    return AppStorage.get<number>(SESSION_REMAINING_DAYS) ?? 0;
  }

  static getLocations(): DirectLocationRecord[] {
    const json: string = AppStorage.get<string>(SESSION_LOCATIONS_JSON) ?? '[]';
    try {
      return JSON.parse(json) as DirectLocationRecord[];
    } catch {
      return [];
    }
  }

  private static applyMe(me: DirectMe): void {
    AppStorage.set<boolean>(SESSION_HAS_PREMIUM, me.hasSubscription === true);
    const name: string = me.username !== undefined && me.username.length > 0
      ? me.username
      : (me.email !== undefined ? me.email : '');
    AppStorage.set<string>(SESSION_DISPLAY_NAME, name);
    AppStorage.set<number>(SESSION_REMAINING_DAYS, me.remainingDays ?? 0);
    AppStorage.set<number>(SESSION_BALANCE_CENTS, me.inAppBalance ?? 0);
  }

  /**
   * If the backend /me response carries a subscriptionUrl, add it to
   * ImportedSubscriptionStore as 'session_subscription', activate it, and
   * fetch+apply the sing-box config so VpnProfileRepository is wired and
   * connectTo() can find a real profile.
   */
  private static async applySubscriptionUrl(me: DirectMe): Promise<void> {
    const subUrl = me.subscriptionUrl;
    if (subUrl === undefined || subUrl.length === 0) {
      return;
    }
    const subId: string = 'session_subscription';
    const now: string = new Date().toISOString();
    const sub: ImportedSubscription = {
      id: subId,
      name: 'Direct VPN',
      url: subUrl,
      singBoxConfig: '',
      addedAt: now
    };
    ImportedSubscriptionStore.add(sub);
    ImportedSubscriptionStore.setActive(subId);
    console.info(`DirectSessionStore: subscription URL found, fetching sing-box config…`);
    try {
      const status: string = await ImportedSubscriptionStore.fetchAndApplyActiveUrl();
      if (status.length > 0) {
        console.info(`DirectSessionStore: ${status}`);
      }
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : `${err}`;
      console.warn(`DirectSessionStore: failed to fetch subscription config: ${msg}`);
    }
  }
}
