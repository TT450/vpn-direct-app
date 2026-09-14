import { vpnExtension, VpnExtensionAbility } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HarmonyCoreBridge } from './HarmonyCoreBridge';

interface VpnProfileEnvelope {
  address?: string;
  dns?: string;
  mtu?: number;
  ipv6?: boolean;
  statePath?: string;
  singBoxConfig?: string;
}

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

    const rawProfile = want.parameters?.['profileJson'];
    if (typeof rawProfile === 'string' && rawProfile.length > 0) {
      this.start(rawProfile).catch((error) => {
        hilog.error(0xD1, 'VPNDirect', 'VPN start failed: %{public}s', JSON.stringify(error));
        this.stop().catch(() => undefined);
      });
    }
  }

  private async start(rawProfileJson: string): Promise<void> {
    if (this.vpnConnection === undefined || this.core === undefined || this.tunFd >= 0) return;

    let profile: VpnProfileEnvelope = {};
    try {
      profile = JSON.parse(rawProfileJson) as VpnProfileEnvelope;
    } catch (error) {
      hilog.error(0xD1, 'VPNDirect', 'Invalid profile envelope: %{public}s', JSON.stringify(error));
      return;
    }

    const singBoxConfig: string = profile.singBoxConfig ?? '';
    const statePath: string = profile.statePath ?? `${this.context.filesDir}/vpn-state.json`;
    if (singBoxConfig.length === 0 || !singBoxConfig.includes('"inbounds"')) {
      hilog.error(0xD1, 'VPNDirect', 'A real sing-box config is required before starting the VPN');
      return;
    }

    const address: string = profile.address ?? '172.19.0.2';
    const dns: string = profile.dns ?? '1.1.1.1';
    const mtu: number = profile.mtu ?? 1400;
    const ipv6: boolean = profile.ipv6 ?? true;

    const config: vpnExtension.VpnConfig = {
      addresses: [{ address: { address, family: 1 }, prefixLength: 32 }],
      routes: [{
        interface: 'vpn-tun',
        destination: { address: { address: '0.0.0.0', family: 1, port: 0 }, prefixLength: 0 },
        gateway: { address: { address: '0.0.0.0', family: 1, port: 0 }, port: 0 },
        hasGateway: false,
        isDefaultRoute: true
      }],
      dnsAddresses: [dns],
      mtu,
      isIPv4Accepted: true,
      isIPv6Accepted: ipv6,
      isInternal: false,
      isBlocking: false,
      trustedApplications: [],
      blockedApplications: []
    };

    try {
      this.vpnId = await this.vpnConnection.generateVpnId();
      config.vpnId = this.vpnId;
      this.tunFd = await this.vpnConnection.create(config);
      if (this.tunFd < 0) {
        this.vpnId = '';
        hilog.error(0xD1, 'VPNDirect', 'VPN TUN creation returned invalid fd');
        return;
      }

      // Protect the extension process before sing-box opens any outbound socket.
      // This keeps the core's control-plane traffic outside the TUN it owns.
      try {
        await this.vpnConnection.protectProcessNet();
      } catch (error) {
        hilog.error(0xD1, 'VPNDirect', 'protectProcessNet failed: %{public}s', JSON.stringify(error));
        await this.destroyVpnConnection();
        return;
      }

      const envelope: string = JSON.stringify({
        statePath,
        singBoxConfig,
        address,
        dns,
        mtu,
        ipv6
      });
      const started: boolean = this.core.start(this.tunFd, envelope);
      if (!started) {
        await this.destroyVpnConnection();
        return;
      }
      hilog.info(0xD1, 'VPNDirect', 'VPN started, tunFd=%{public}d', this.tunFd);
    } catch (error) {
      await this.destroyVpnConnection();
      hilog.error(0xD1, 'VPNDirect', 'VPN setup failed: %{public}s', JSON.stringify(error));
    }
  }

  private async stop(): Promise<void> {
    if (this.stopping) return;
    this.stopping = true;
    try {
      this.core?.stop();
    } finally {
      await this.destroyVpnConnection();
      this.stopping = false;
    }
  }

  private async destroyVpnConnection(): Promise<void> {
    if (this.vpnConnection !== undefined && this.vpnId.length > 0) {
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
    this.stop().catch((error) => {
      hilog.error(0xD1, 'VPNDirect', 'VPN cleanup failed: %{public}s', JSON.stringify(error));
    });
    hilog.info(0xD1, 'VPNDirect', 'VPN extension destroyed');
  }
}
