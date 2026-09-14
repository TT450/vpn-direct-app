import { vpnExtension } from '@kit.NetworkKit';
import { Want, common } from '@kit.AbilityKit';
import { AppShell } from '../app/AppShell';
import { DirectVpnProfile, VpnProfileRepository } from '../vpn/VpnProfileRepository';
import { VpnServerSelection, SelectedVpnServer } from '../vpn/VpnServerSelection';
import { VpnStateStore, VpnRuntimeState } from '../vpn/VpnStateStore';

@Entry
@Component
struct Index {
  @State private status: string = 'Disconnected';
  @State private connecting: boolean = false;
  @State private serverName: string = 'Авто';
  private desiredServerId: string = 'auto';
  private activeServerId: string = '';
  private stateTimer: number = -1;
  private switchInProgress: boolean = false;
  private appContext?: common.UIAbilityContext;
  private readonly bundleName: string = 'com.vpndirect.vpndirectapp';
  private readonly extensionName: string = 'VpnDirectVpnExtension';

  aboutToAppear(): void {
    this.appContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.syncSelectedServer();
    this.syncRuntimeState();
    this.stateTimer = setInterval(() => { this.syncSelectedServer(); this.syncRuntimeState(); }, 250);
  }

  aboutToDisappear(): void {
    if (this.stateTimer >= 0) { clearInterval(this.stateTimer); this.stateTimer = -1; }
  }

  private syncSelectedServer(): void {
    const selected: SelectedVpnServer = VpnServerSelection.get();
    this.desiredServerId = selected.id;
    this.serverName = selected.displayName;
    if (this.status === 'Connected' && this.activeServerId.length > 0 && this.desiredServerId !== this.activeServerId && !this.switchInProgress) {
      this.switchServer(this.desiredServerId);
    }
  }

  private syncRuntimeState(): void {
    if (this.appContext === undefined) return;
    const runtime: VpnRuntimeState | null = VpnStateStore.readFresh(this.appContext, 8000);
    if (runtime === null) {
      if (this.status === 'Connected' || this.status === 'Disconnecting') {
        this.status = 'Disconnected';
        this.connecting = false;
      }
      return;
    }
    switch (runtime.state) {
      case 'Connecting': this.status = 'Connecting'; break;
      case 'Connected': this.status = 'Connected'; this.connecting = false; break;
      case 'Disconnecting': this.status = 'Disconnecting'; break;
      case 'Disconnected': this.status = 'Disconnected'; this.connecting = false; break;
      case 'Failed': this.status = 'Connection failed'; this.connecting = false; break;
      default: break;
    }
  }

  private async waitForState(expected: string, timeoutMs: number): Promise<boolean> {
    const startedAt: number = Date.now();
    while (Date.now() - startedAt < timeoutMs) {
      if (this.appContext !== undefined) {
        const runtime: VpnRuntimeState | null = VpnStateStore.read(this.appContext);
        if (runtime !== null && runtime.state === expected) return true;
      }
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 100));
    }
    return false;
  }

  private vpnWant(profile: DirectVpnProfile): Want {
    const statePath: string = this.appContext === undefined ? '' : VpnStateStore.path(this.appContext);
    return {
      deviceId: '', bundleName: this.bundleName, abilityName: this.extensionName,
      parameters: { profileJson: JSON.stringify({ statePath, singBoxConfig: profile.singBoxConfig, address: profile.address, ipv6Address: profile.ipv6Address, dns: profile.dns, mtu: profile.mtu, ipv6: profile.ipv6 }) }
    };
  }

  private async connectTo(serverId: string): Promise<boolean> {
    const profile: DirectVpnProfile | null = await VpnProfileRepository.getProfile(serverId);
    if (profile === null || profile.singBoxConfig.length === 0) { console.error(`VPN Direct: no real sing-box profile for ${serverId}`); return false; }
    try { await vpnExtension.startVpnExtensionAbility(this.vpnWant(profile)); this.activeServerId = serverId; return true; }
    catch (error) { console.error(`VPN Direct: start failed ${JSON.stringify(error)}`); return false; }
  }

  private async connect(): Promise<void> {
    if (this.connecting || this.status === 'Connected' || this.status === 'Connecting') return;
    this.connecting = true; this.status = 'Connecting';
    try { if (!(await this.connectTo(this.desiredServerId))) this.status = 'Connection failed'; }
    finally { this.connecting = false; this.syncRuntimeState(); }
  }

  private async disconnect(): Promise<boolean> {
    if (this.status === 'Disconnected') return true;
    if (this.status === 'Disconnecting') return await this.waitForState('Disconnected', 10000);
    this.connecting = true; this.status = 'Disconnecting';
    try {
      await vpnExtension.stopVpnExtensionAbility({ deviceId: '', bundleName: this.bundleName, abilityName: this.extensionName });
      const stopped: boolean = await this.waitForState('Disconnected', 10000);
      if (!stopped) this.status = 'Disconnect failed';
      return stopped;
    } catch (error) { this.status = 'Disconnect failed'; console.error(`VPN Direct: stop failed ${JSON.stringify(error)}`); return false; }
    finally { this.connecting = false; this.syncRuntimeState(); }
  }

  private async switchServer(targetServerId: string): Promise<void> {
    if (this.switchInProgress || this.status !== 'Connected') return;
    this.switchInProgress = true;
    const disconnected: boolean = await this.disconnect();
    if (disconnected && this.desiredServerId === targetServerId) await this.connect();
    this.switchInProgress = false;
  }

  build() {
    AppShell({ status: this.status, serverName: this.serverName, onToggle: () => {
      if (this.status === 'Connected' || this.status === 'Connecting') this.disconnect(); else this.connect();
    }, onServerTap: () => this.syncSelectedServer() });
  }
}
