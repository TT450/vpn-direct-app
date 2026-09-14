export interface DirectVpnProfile {
  id: string;
  serverName: string;
  singBoxConfig: string;
  address: string;
  dns: string;
  mtu: number;
  ipv6: boolean;
}

export interface DirectVpnProfileProvider {
  getProfile(serverId: string): Promise<DirectVpnProfile | null>;
}

/**
 * Backend seam for VPN profiles.
 *
 * The production API adapter should implement DirectVpnProfileProvider and
 * return a fully validated sing-box JSON config. UI and the VPN extension do
 * not know how that config was obtained.
 */
export class VpnProfileRepository {
  private static provider: DirectVpnProfileProvider | undefined;

  static setProvider(provider: DirectVpnProfileProvider): void {
    VpnProfileRepository.provider = provider;
  }

  static async getProfile(serverId: string): Promise<DirectVpnProfile | null> {
    if (VpnProfileRepository.provider === undefined) {
      return null;
    }
    return VpnProfileRepository.provider.getProfile(serverId);
  }
}
