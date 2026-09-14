/**
 * Public injectable Direct backend bindings. Defaults are empty / fail-closed (safe for GitHub).
 * Optional `localInstaller` is set by a private DirectBackendLocal.ets override (skip-worktree).
 * Never put hosts or routes in this file.
 */
import { common } from '@kit.AbilityKit';

export type LocalInstaller = (ctx?: common.UIAbilityContext) => void;

export interface DirectLocationRecord {
  id: string;
  countryCode: string;
  country: string;
  city: string;
  region: string;
  /** Optional server host for latency probing. Empty-string default (safe for GitHub). */
  host?: string;
}

export interface DirectBalanceTransaction {
  id: string;
  kind: string;
  amountUsdCents: number;
  title: string;
  createdAt: string;
  debit: boolean;
}

export interface DirectBalanceSnapshot {
  usdCents: number;
  transactions: DirectBalanceTransaction[];
}

export interface DirectMe {
  authenticated?: boolean;
  email?: string;
  username?: string;
  phone?: string;
  inAppBalance?: number;
  hasSubscription?: boolean;
  subscriptionUrl?: string;
  remainingDays?: number;
}

export interface DirectAppCatalog {
  currency: string;
  tariffs: Object[];
  constructor: Object | null;
  addons: Object | null;
  monthMultipliers: Record<string, number>;
}

export interface DirectCheckoutQuoteRequest {
  productKind: string;
  tariffId?: number;
  days?: number;
  devices?: number;
  trafficGb?: number;
}

export interface DirectCheckoutQuote {
  productKind?: string;
  amount?: number;
  currency?: string;
  days?: number;
  devices?: number;
  trafficGb?: number;
  title?: string;
  planName?: string;
  error?: string;
}

export interface DirectCheckoutStatus {
  paymentId?: string;
  status?: string;
  fulfilled?: boolean;
  amount?: number;
  title?: string;
  subscriptionUrl?: string;
  error?: string;
}

export interface DirectAccountDevice {
  id: string;
  label: string;
  detail: string;
  isCurrent: boolean;
}

export interface DirectAccountPayment {
  id: string;
  title: string;
  subtitle: string;
  amountLabel: string;
  statusLabel: string;
  isRefundLike: boolean;
}

export interface DirectPromoRedeemResult {
  ok: boolean;
  message: string;
}

function notImplemented(name: string): Error {
  return new Error(`${name} is not available in this build`);
}

export class DirectBackendRuntime {
  /** Set by EntryAbility before warmUp so local Preferences can open. */
  static appContext: common.UIAbilityContext | null = null;

  /**
   * Optional local-only installer. Public stub leaves this null.
   * Private DirectBackendLocal.ets (skip-worktree) assigns a hook that wires *.local.ets.
   */
  static localInstaller: LocalInstaller | null = null;

  static host: string = '';
  static baseURLString: string = '';
  static legacyIP: string = '';
  static subscriptionHost: string = '';
  static subscriptionBaseURLString: string = '';
  static googleClientID: string = '';
  static googleRedirectURI: string = 'vpndirect:/oauth2redirect/google';
  /** Allowed hosts for external-checkout return signal only. Empty on public GitHub. */
  static checkoutSuccessHostSuffixes: string[] = [];

  static ownedHosts: () => string[] = (): string[] => [];

  static isAuthenticated: () => boolean = (): boolean => false;

  static fetchLocations: () => Promise<DirectLocationRecord[]> = async (): Promise<DirectLocationRecord[]> => [];

  static fetchBalanceSnapshot: (() => Promise<DirectBalanceSnapshot>) | null = null;

  static loginWithPassword: ((email: string, password: string) => Promise<DirectMe>) | null = null;
  static registerWithPassword:
    ((name: string, email: string, password: string, confirmation: string) => Promise<DirectMe>) | null = null;
  static sendEmailCode: ((email: string) => Promise<void>) | null = null;
  static verifyEmailCode: ((email: string, code: string) => Promise<DirectMe>) | null = null;
  static requestPasswordReset: ((email: string) => Promise<boolean>) | null = null;

  static logout: (() => Promise<void>) | null = null;
  static deleteAccount: (() => Promise<void>) | null = null;
  static fetchMe: (() => Promise<DirectMe>) | null = null;
  static refreshAccount: (() => Promise<DirectMe | null>) | null = null;
  static bootstrapSession: (() => Promise<void>) | null = null;

  static fetchAppCatalog: () => Promise<DirectAppCatalog> = async (): Promise<DirectAppCatalog> => {
    return { currency: 'RUB', tariffs: [], constructor: null, addons: null, monthMultipliers: {} };
  };
  static quoteCheckout: ((req: DirectCheckoutQuoteRequest) => Promise<DirectCheckoutQuote>) | null = null;
  static checkoutStatus: ((paymentId: string) => Promise<DirectCheckoutStatus>) | null = null;

  static fetchAccountDevices: () => Promise<DirectAccountDevice[]> = async (): Promise<DirectAccountDevice[]> => [];
  static revokeAccountDevice: (deviceId: string) => Promise<void> = async (_deviceId: string): Promise<void> => {
    throw notImplemented('revokeAccountDevice');
  };
  static fetchAccountPayments: () => Promise<DirectAccountPayment[]> = async (): Promise<DirectAccountPayment[]> => [];
  static redeemPromo: (code: string) => Promise<DirectPromoRedeemResult> = async (_code: string): Promise<DirectPromoRedeemResult> => {
    return { ok: false, message: 'Сервис промокодов недоступен' };
  };
  static submitSupport: (category: string, body: string) => Promise<void> = async (_c: string, _b: string): Promise<void> => {
    throw notImplemented('submitSupport');
  };
  static prepareAccountLink: (method: string) => Promise<string> = async (method: string): Promise<string> => {
    return `Подтвердите владение способом входа «${method}» — подписки не объединяются автоматически.`;
  };

  static checkoutReturnHostAllowed(host: string, allowlist?: string[]): boolean {
    const h = host.trim().toLowerCase();
    if (h.length === 0) {
      return false;
    }
    const list = (allowlist ?? DirectBackendRuntime.checkoutSuccessHostSuffixes)
      .map((entry: string) => entry.trim().toLowerCase())
      .filter((entry: string) => entry.length > 0);
    for (let i = 0; i < list.length; i++) {
      const entry = list[i];
      if (h === entry || h.endsWith('.' + entry)) {
        return true;
      }
    }
    return false;
  }

  /** Invokes localInstaller when a private DirectBackendLocal override registered one. */
  static warmUp(context?: common.UIAbilityContext): void {
    if (context) {
      DirectBackendRuntime.appContext = context;
    }
    const install = DirectBackendRuntime.localInstaller;
    if (install) {
      install(context);
    }
  }
}
