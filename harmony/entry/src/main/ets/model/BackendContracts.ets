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

export interface SubscriptionSummary {
  id: string;
  planName: string;
  expiresAt: number;
  profiles: DirectVpnProfile[];
}

export interface SubscriptionRepository {
  getCurrent(): Promise<SubscriptionSummary | null>;
  getPlans(): Promise<Array<Record<string, Object>>>;
  activate(planId: string): Promise<SubscriptionSummary>;
  cancel(subscriptionId: string): Promise<void>;
}

export interface BalanceRepository {
  getBalance(): Promise<number>;
  getHistory(): Promise<Array<Record<string, Object>>>;
}

export interface ImportRepository {
  importText(value: string): Promise<DirectVpnProfile>;
  importFile(path: string): Promise<DirectVpnProfile>;
}

export interface AccountRepository {
  getAccount(): Promise<Record<string, Object>>;
  getDevices(): Promise<Array<Record<string, Object>>>;
  revokeDevice(deviceId: string): Promise<void>;
}
