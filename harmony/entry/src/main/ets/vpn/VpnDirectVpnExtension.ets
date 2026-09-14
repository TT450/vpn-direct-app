import { vpnExtension, VpnExtensionAbility } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HarmonyCoreBridge } from './HarmonyCoreBridge';

/**
 * VPN Direct HarmonyOS NEXT platform adapter.
 *
 * This is a third-party VPN extension. The system starts this ability after
 * the user grants VPN trust through the system VPN authorization flow.
 * The application uses vpnExtension, not the system-only @ohos.net.vpn API.
 */
export default class VpnDirectVpnExtension extends VpnExtensionAbility {
  private vpnConnection?: vpnExtension.VpnConnection;
  private vpnId: string = '';
  private tunFd: number = -1;
  private core?: HarmonyCoreBridge;
  private stopping: boolean = false;

  onCreate(want: Want): void {
    hilog.info(0xD1, 'VPNDirect', 'VPN extension created');
    this.vpnConnection = vpnExtension.createVpnConnection(this.context);
    this.core = new HarmonyCoreBridge();

    const parameters = want.parameters as Record<string, Object> | undefined;
    const profileJson = this.stringValue(parameters?.['profileJson'], '');
    if (profileJson.length > 0) {
      this.start(profileJson).catch((error: Error) => {
        hilog.error(0xD1, 'VPNDirect', 'VPN start failed: %{public}s', error.message);
        this.stop().catch(() => undefined);
      });
    }
  }

  private async start(profileJson: string): Promise<void> {
    if (!this.vpnConnection || !this.core) {
      throw new Error('VPN extension is not initialized');
    }
    if (this.tunFd >= 0) {
      return;
    }

    const profile = JSON.parse(profileJson) as Record<string, Object>;
    const address = this.stringValue(profile['address'], '172.19.0.2');
    const dns = this.stringValue(profile['dns'], '1.1.1.1');
    const mtu = this.numberValue(profile['mtu'], 1400);
    const ipv6 = this.booleanValue(profile['ipv6'], true);

    // VPN Config is platform routing/TUN state. It does not contain or load
    // executable code. The actual tunnel protocol is implemented by Core.
    const config = {
      addresses: [{ address, prefixLength: 32 }],
      routes: [{ address: '0.0.0.0', prefixLength: 0 }],
      dnsAddresses: [dns],
      mtu,
      isIPv4Accepted: true,
      isIPv6Accepted: ipv6,
      isInternal: false,
      isBlocking: false
    };

    this.vpnId = await this.vpnConnection.generateVpnId();
    this.tunFd = await this.vpnConnection.create(config);
    if (this.tunFd < 0) {
      this.vpnId = '';
      throw new Error('HarmonyOS VPN TUN creation failed');
    }

    try {
      await this.core.start(this.tunFd, profileJson);
      hilog.info(0xD1, 'VPNDirect', 'VPN started, tunFd=%{public}d', this.tunFd);
    } catch (error) {
      await this.destroyVpnConnection();
      throw error;
    }
  }

  private async stop(): Promise<void> {
    if (this.stopping) {
      return;
    }
    this.stopping = true;
    try {
      await this.core?.stop();
    } finally {
      await this.destroyVpnConnection();
      this.stopping = false;
    }
  }

  private async destroyVpnConnection(): Promise<void> {
    if (this.vpnConnection && this.vpnId.length > 0) {
      try {
        await this.vpnConnection.destroy(this.vpnId);
      } catch (error) {
        hilog.error(0xD1, 'VPNDirect', 'VPN destroy failed: %{public}s', JSON.stringify(error));
      }
    }
    this.vpnId = '';
    this.tunFd = -1;
  }

  onDestroy(): void {
    this.stop().catch((error: Error) => {
      hilog.error(0xD1, 'VPNDirect', 'VPN cleanup failed: %{public}s', error.message);
    });
    hilog.info(0xD1, 'VPNDirect', 'VPN extension destroyed');
  }

  private stringValue(value: Object | undefined, fallback: string): string {
    return typeof value === 'string' && value.length > 0 ? value : fallback;
  }

  private numberValue(value: Object | undefined, fallback: number): number {
    return typeof value === 'number' && value > 0 ? value : fallback;
  }

  private booleanValue(value: Object | undefined, fallback: boolean): boolean {
    return typeof value === 'boolean' ? value : fallback;
  }
}
