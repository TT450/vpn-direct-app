import { DirectVpnProfile } from '../vpn/VpnProfileRepository';

export interface AuthSession {
  userId: string;
  email?: string;
  phone?: string;
}

export interface AuthRepository {
  login(identifier: string, secret: string): Promise<AuthSession>;
  register(identifier: string, secret: string): Promise<AuthSession>;
  sendCode(identifier: string): Promise<void>;
  verifyCode(identifier: string, code: string): Promise<AuthSession>;
  logout(): Promise<void>;
}

export interface PlanSummary {
  id: string;
  name: string;
  price: number;
  durationDays: number;
}

export interface SubscriptionSummary {
  id: string;
  planName: string;
  expiresAt: number;
  profiles: DirectVpnProfile[];
}

export interface SubscriptionRepository {
  getCurrent(): Promise<SubscriptionSummary | null>;
  getPlans(): Promise<PlanSummary[]>;
  activate(planId: string): Promise<SubscriptionSummary>;
  cancel(subscriptionId: string): Promise<void>;
}

export interface BalanceTransaction {
  id: string;
  amount: number;
  currency: string;
  createdAt: number;
  status: string;
}

export interface BalanceRepository {
  getBalance(): Promise<number>;
  getHistory(): Promise<BalanceTransaction[]>;
}

export interface ImportRepository {
  importText(value: string): Promise<DirectVpnProfile>;
  importFile(path: string): Promise<DirectVpnProfile>;
}

export interface AccountSummary {
  userId: string;
  email?: string;
  phone?: string;
  displayName?: string;
}

export interface DeviceSummary {
  id: string;
  name: string;
  lastSeenAt: number;
  current: boolean;
}

export interface AccountRepository {
  getAccount(): Promise<AccountSummary>;
  getDevices(): Promise<DeviceSummary[]>;
  revokeDevice(deviceId: string): Promise<void>;
}
