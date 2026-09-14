import { vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { AppShell } from '../app/AppShell';
import { VpnProfileRepository, DirectVpnProfile } from '../vpn/VpnProfileRepository';
import { VpnStateStore, VpnRuntimeState } from '../vpn/VpnStateStore';

@Entry
@Component
struct Index {
  @State private status: string = 'Disconnected';
  @State private connecting: boolean = false;
  @State private serverName: string = 'Авто';
  private serverId: string = 'auto';
  private stateTimer: number = -1;
  private appContext?: common.UIAbilityContext;
  private readonly bundleName: string = 'com.vpndirect.vpndirectapp';
  private readonly extensionName: string = 'VpnDirectVpnExtension';

  aboutToAppear(): void {
    this.appContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.syncRuntimeState();
    this.stateTimer = setInterval(() => this.syncRuntimeState(), 250);
  }

  aboutToDisappear(): void {
    if (this.stateTimer >= 0) {
      clearInterval(this.stateTimer);
      this.stateTimer = -1;
    }
  }

  private syncRuntimeState(): void {
    if (this.appContext === undefined) return;
    const runtime: VpnRuntimeState | null = VpnStateStore.read(this.appContext);
    if (runtime === null) return;

    switch (runtime.state) {
      case 'Connecting':
        this.status = 'Connecting';
        break;
      case 'Connected':
        this.status = 'Connected';
        this.connecting = false;
        break;
      case 'Disconnecting':
        this.status = 'Disconnecting';
        break;
      case 'Disconnected':
        this.status = 'Disconnected';
        this.connecting = false;
        break;
      case 'Failed':
        this.status = 'Connection failed';
        this.connecting = false;
        break;
      default:
        break;
    }
  }

  private vpnWant(profile: DirectVpnProfile): Want {
    const statePath: string = this.appContext === undefined
      ? ''
      : VpnStateStore.path(this.appContext);
    return {
      deviceId: '',
      bundleName: this.bundleName,
      abilityName: this.extensionName,
      parameters: {
        profileJson: JSON.stringify({
          statePath,
          singBoxConfig: profile.singBoxConfig,
          address: profile.address,
          dns: profile.dns,
          mtu: profile.mtu,
          ipv6: profile.ipv6
        })
      }
    };
  }

  private async connect(): Promise<void> {
    if (this.connecting || this.status === 'Connected' || this.status === 'Connecting') return;
    this.connecting = true;
    this.status = 'Connecting';

    try {
      const profile: DirectVpnProfile | null = await VpnProfileRepository.getProfile(this.serverId);
      if (profile === null || profile.singBoxConfig.length === 0) {
        this.status = 'Connection failed';
        this.connecting = false;
        console.error('VPN Direct: no real sing-box profile is configured');
        return;
      }
      await vpnExtension.startVpnExtensionAbility(this.vpnWant(profile));
    } catch (error) {
      this.status = 'Connection failed';
      console.error(`VPN Direct: start failed ${JSON.stringify(error)}`);
    } finally {
      this.connecting = false;
      this.syncRuntimeState();
    }
  }

  private async disconnect(): Promise<void> {
    if (this.connecting || this.status === 'Disconnected' || this.status === 'Disconnecting') return;
    this.connecting = true;
    this.status = 'Disconnecting';
    try {
      await vpnExtension.stopVpnExtensionAbility({
        deviceId: '',
        bundleName: this.bundleName,
        abilityName: this.extensionName
      });
    } catch (error) {
      this.status = 'Disconnect failed';
      console.error(`VPN Direct: stop failed ${JSON.stringify(error)}`);
    } finally {
      this.connecting = false;
      this.syncRuntimeState();
    }
  }

  private selectServer(): void {
    if (this.status === 'Connected' || this.status === 'Connecting' || this.status === 'Disconnecting') return;
    if (this.serverId === 'auto') {
      this.serverId = 'de-frankfurt';
      this.serverName = 'Германия · Frankfurt';
    } else {
      this.serverId = 'auto';
      this.serverName = 'Авто';
    }
  }

  build() {
    AppShell({ status: this.status, serverName: this.serverName, onToggle: () => {
      if (this.status === 'Connected' || this.status === 'Connecting') {
        this.disconnect();
      } else {
        this.connect();
      }
    }, onServerTap: () => this.selectServer() });
  }
}
