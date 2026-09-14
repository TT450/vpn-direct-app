import { connection, vpnExtension, VpnExtensionAbility } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HarmonyCoreBridge } from './HarmonyCoreBridge';

interface VpnProfileEnvelope {
  address?: string;
  ipv6Address?: string;
  dns?: string;
  mtu?: number;
  ipv6?: boolean;
  statePath?: string;
  singBoxConfig?: string;
}

interface CoreEnvelope {
  statePath: string;
  singBoxConfig: string;
  address: string;
  ipv6Address: string;
  dns: string;
  mtu: number;
  ipv6: boolean;
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
      this.start(rawProfile).catch((error: BusinessError) => {
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
      const err = error as BusinessError;
      hilog.error(0xD1, 'VPNDirect', 'Invalid profile envelope: %{public}s', JSON.stringify(err));
      return;
    }

    const singBoxConfig: string = profile.singBoxConfig ?? '';
    const statePath: string = profile.statePath ?? `${this.context.filesDir}/vpn-state.json`;
    if (singBoxConfig.length === 0 || !singBoxConfig.includes('"inbounds"')) {
      hilog.error(0xD1, 'VPNDirect', 'A real sing-box config is required before starting the VPN');
      return;
    }

    const address: string = profile.address ?? '172.19.0.2';
    const ipv6Address: string = profile.ipv6Address ?? 'fd00:1:1::2';
    const dns: string = profile.dns ?? '1.1.1.1';
    const mtu: number = profile.mtu ?? 1400;
    const ipv6: boolean = profile.ipv6 ?? true;

    const v4Net: connection.NetAddress = { address: address, family: 1, port: 0 };
    const v4Link: vpnExtension.LinkAddress = { address: v4Net, prefixLength: 32 };
    const v4DestNet: connection.NetAddress = { address: '0.0.0.0', family: 1, port: 0 };
    const v4Dest: vpnExtension.LinkAddress = { address: v4DestNet, prefixLength: 0 };
    const v4Gw: connection.NetAddress = { address: '0.0.0.0', family: 1, port: 0 };
    const v4Route: vpnExtension.RouteInfo = {
      interface: 'vpn-tun',
      destination: v4Dest,
      gateway: v4Gw,
      hasGateway: false,
      isDefaultRoute: true
    };

    const addresses: Array<vpnExtension.LinkAddress> = [v4Link];
    const routes: Array<vpnExtension.RouteInfo> = [v4Route];

    if (ipv6) {
      const v6Net: connection.NetAddress = { address: ipv6Address, family: 2, port: 0 };
      const v6Link: vpnExtension.LinkAddress = { address: v6Net, prefixLength: 128 };
      const v6DestNet: connection.NetAddress = { address: '::', family: 2, port: 0 };
      const v6Dest: vpnExtension.LinkAddress = { address: v6DestNet, prefixLength: 0 };
      const v6Gw: connection.NetAddress = { address: '::', family: 2, port: 0 };
      const v6Route: vpnExtension.RouteInfo = {
        interface: 'vpn-tun',
        destination: v6Dest,
        gateway: v6Gw,
        hasGateway: false,
        isDefaultRoute: true
      };
      addresses.push(v6Link);
      routes.push(v6Route);
    }

    const emptyApps: Array<string> = [];
    const dnsList: Array<string> = [dns];
    const config: vpnExtension.VpnConfig = {
      addresses: addresses,
      routes: routes,
      dnsAddresses: dnsList,
      mtu: mtu,
      isIPv4Accepted: true,
      isIPv6Accepted: ipv6,
      isInternal: false,
      isBlocking: false,
      trustedApplications: emptyApps,
      blockedApplications: emptyApps
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

      try {
        await this.vpnConnection.protectProcessNet();
      } catch (error) {
        const err = error as BusinessError;
        hilog.error(0xD1, 'VPNDirect', 'protectProcessNet failed: %{public}s', JSON.stringify(err));
        await this.destroyVpnConnection();
        return;
      }

      const envelopeObj: CoreEnvelope = {
        statePath: statePath,
        singBoxConfig: singBoxConfig,
        address: address,
        ipv6Address: ipv6Address,
        dns: dns,
        mtu: mtu,
        ipv6: ipv6
      };
      const envelope: string = JSON.stringify(envelopeObj);
      const started: boolean = this.core.start(this.tunFd, envelope);
      if (!started) {
        await this.destroyVpnConnection();
        return;
      }
      hilog.info(0xD1, 'VPNDirect', 'VPN started, tunFd=%{public}d', this.tunFd);
    } catch (error) {
      await this.destroyVpnConnection();
      const err = error as BusinessError;
      hilog.error(0xD1, 'VPNDirect', 'VPN setup failed: %{public}s', JSON.stringify(err));
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
        const err = error as BusinessError;
        hilog.error(0xD1, 'VPNDirect', 'VPN destroy failed: %{public}s', JSON.stringify(err));
      }
    }
    this.vpnId = '';
    this.tunFd = -1;
  }

  onDestroy(): void {
    this.stop().catch((error: BusinessError) => {
      hilog.error(0xD1, 'VPNDirect', 'VPN cleanup failed: %{public}s', JSON.stringify(error));
    });
    hilog.info(0xD1, 'VPNDirect', 'VPN extension destroyed');
  }
}
