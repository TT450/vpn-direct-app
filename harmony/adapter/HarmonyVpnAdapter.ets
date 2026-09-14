import { VpnExtensionAbility, vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';

/**
 * HarmonyOS platform boundary for VPN Direct.
 *
 * This class intentionally owns only HarmonyOS VPN lifecycle and TUN setup.
 * The portable VPN engine must remain outside this adapter and be connected
 * through a native bridge/tun2socks layer.
 */
export class HarmonyVpnAdapter extends VpnExtensionAbility {
  private vpnConnection?: vpnExtension.VpnConnection;

  onCreate(want: Want): void {
    this.vpnConnection = vpnExtension.createVpnConnection(this.context);
  }

  onDestroy(): void {
    this.vpnConnection = undefined;
  }

  get isCreated(): boolean {
    return this.vpnConnection !== undefined;
  }
}

/**
 * Small interface kept platform-neutral so the future native bridge can
 * expose exactly the operations required by VPNDirectCore.
 */
export interface HarmonyCoreBridge {
  start(configJson: string, tunFd: number): Promise<void>;
  stop(): Promise<void>;
  version(): string;
}
