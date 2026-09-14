import { DirectBackendRuntime, DirectMe, DirectLocationRecord } from '../backend/DirectBackendRuntime';
import { ImportedSubscriptionStore, ImportedSubscription } from '../vpn/ImportedSubscriptionStore';

export const SESSION_HAS_SUBSCRIPTION: string = 'session_has_subscription';
export const SESSION_HAS_PREMIUM: string = SESSION_HAS_SUBSCRIPTION;
export const SESSION_AUTHENTICATED: string = 'session_authenticated';
export const SESSION_AUTH_METHOD: string = 'session_auth_method';
export const SESSION_ACCOUNT_KIND: string = 'session_account_kind';
export const SESSION_SUBSCRIPTION_URL: string = 'session_subscription_url';
export const SESSION_DISPLAY_NAME: string = 'session_display_name';
export const SESSION_PLAN_NAME: string = 'session_plan_name';
export const SESSION_REMAINING_DAYS: string = 'session_remaining_days';
export const SESSION_BALANCE_CENTS: string = 'session_balance_cents';
export const SESSION_TRAFFIC_USED_GB: string = 'session_traffic_used_gb';
export const SESSION_TRAFFIC_LIMIT_GB: string = 'session_traffic_limit_gb';
export const SESSION_LOADED: string = 'session_loaded';
export const SESSION_ERROR: string = 'session_error';
export const SESSION_LOCATIONS_JSON: string = 'session_locations_json';

export class DirectSessionStore {
  static init(): void {
    AppStorage.setOrCreate<boolean>(SESSION_HAS_SUBSCRIPTION, false); AppStorage.setOrCreate<boolean>(SESSION_AUTHENTICATED, false); AppStorage.setOrCreate<string>(SESSION_AUTH_METHOD, ''); AppStorage.setOrCreate<string>(SESSION_ACCOUNT_KIND, ''); AppStorage.setOrCreate<string>(SESSION_SUBSCRIPTION_URL, ''); AppStorage.setOrCreate<string>(SESSION_DISPLAY_NAME, ''); AppStorage.setOrCreate<string>(SESSION_PLAN_NAME, ''); AppStorage.setOrCreate<number>(SESSION_REMAINING_DAYS, 0); AppStorage.setOrCreate<number>(SESSION_BALANCE_CENTS, 0); AppStorage.setOrCreate<number>(SESSION_TRAFFIC_USED_GB, 0); AppStorage.setOrCreate<number>(SESSION_TRAFFIC_LIMIT_GB, 0); AppStorage.setOrCreate<boolean>(SESSION_LOADED, false); AppStorage.setOrCreate<string>(SESSION_ERROR, ''); AppStorage.setOrCreate<string>(SESSION_LOCATIONS_JSON, '[]');
  }
  static async refresh(): Promise<void> { AppStorage.set<boolean>(SESSION_LOADED, false); AppStorage.set<string>(SESSION_ERROR, ''); try { const bootstrap = DirectBackendRuntime.bootstrapSession; if (bootstrap !== null && bootstrap !== undefined) await bootstrap(); const fetchMe = DirectBackendRuntime.fetchMe; if (fetchMe !== null && fetchMe !== undefined) { const me: DirectMe = await fetchMe(); DirectSessionStore.applyMe(me); await DirectSessionStore.applySubscriptionUrl(me); } const locations: DirectLocationRecord[] = await DirectBackendRuntime.fetchLocations(); AppStorage.set<string>(SESSION_LOCATIONS_JSON, JSON.stringify(locations)); } catch (err) { const msg = err instanceof Error ? err.message : `${err}`; AppStorage.set<string>(SESSION_ERROR, msg.length > 0 ? msg : 'Не удалось загрузить данные'); } finally { AppStorage.set<boolean>(SESSION_LOADED, true); } }
  static hasSubscription(): boolean { return AppStorage.get<boolean>(SESSION_HAS_SUBSCRIPTION) ?? false; }
  static hasPremium(): boolean { return DirectSessionStore.hasSubscription(); }
  static displayName(): string { return AppStorage.get<string>(SESSION_DISPLAY_NAME) ?? ''; }
  static planName(): string { return AppStorage.get<string>(SESSION_PLAN_NAME) ?? ''; }
  static remainingDays(): number { return AppStorage.get<number>(SESSION_REMAINING_DAYS) ?? 0; }
  static getLocations(): DirectLocationRecord[] { const json = AppStorage.get<string>(SESSION_LOCATIONS_JSON) ?? '[]'; try { return JSON.parse(json) as DirectLocationRecord[]; } catch { return []; } }
  private static applyMe(me: DirectMe): void { AppStorage.set<boolean>(SESSION_AUTHENTICATED, me.authenticated === true); AppStorage.set<string>(SESSION_AUTH_METHOD, me.authMethod ?? ''); AppStorage.set<string>(SESSION_ACCOUNT_KIND, me.accountKind ?? ''); AppStorage.set<string>(SESSION_SUBSCRIPTION_URL, me.subscriptionUrl ?? ''); const name = me.username !== undefined && me.username.length > 0 ? me.username : (me.email !== undefined ? me.email : ''); AppStorage.set<string>(SESSION_DISPLAY_NAME, name); AppStorage.set<string>(SESSION_PLAN_NAME, me.planName ?? ''); AppStorage.set<boolean>(SESSION_HAS_SUBSCRIPTION, me.hasSubscription === true); AppStorage.set<number>(SESSION_REMAINING_DAYS, me.remainingDays ?? 0); AppStorage.set<number>(SESSION_BALANCE_CENTS, me.inAppBalance ?? 0); AppStorage.set<number>(SESSION_TRAFFIC_USED_GB, Math.max(0, me.trafficUsedGB ?? 0)); AppStorage.set<number>(SESSION_TRAFFIC_LIMIT_GB, Math.max(0, me.trafficLimitGB ?? 0)); }
  private static async applySubscriptionUrl(me: DirectMe): Promise<void> { const subUrl = me.subscriptionUrl; if (subUrl === undefined || subUrl.length === 0) return; const subId = 'session_subscription'; const now = new Date().toISOString(); const sub: ImportedSubscription = { id: subId, name: me.planName && me.planName.length > 0 ? me.planName : 'Direct VPN', url: subUrl, singBoxConfig: '', addedAt: now }; ImportedSubscriptionStore.add(sub); ImportedSubscriptionStore.setActive(subId); try { await ImportedSubscriptionStore.fetchAndApplyActiveUrl(); } catch (err) { const msg = err instanceof Error ? err.message : `${err}`; console.warn(`DirectSessionStore: failed to fetch subscription config: ${msg}`); } }
}
