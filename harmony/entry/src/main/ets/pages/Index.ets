import { vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { AppShell } from '../app/AppShell';

@Entry
@Component
struct Index {
  @State private status: string = 'Disconnected';
  @State private connecting: boolean = false;
  @State private serverName: string = 'Авто';
  private readonly bundleName: string = 'com.vpndirect.vpndirectapp';
  private readonly extensionName: string = 'VpnDirectVpnExtension';

  private vpnWant(): Want {
    return {
      deviceId: '',
      bundleName: this.bundleName,
      abilityName: this.extensionName,
      parameters: {
        profileJson: JSON.stringify({ address: '172.19.0.2', dns: '1.1.1.1', mtu: 1400, ipv6: true })
      }
    };
  }

  private async connect(): Promise<void> {
    if (this.connecting || this.status === 'Connected') return;
    this.connecting = true;
    this.status = 'Connecting';
    try {
      await vpnExtension.startVpnExtensionAbility(this.vpnWant());
      this.status = 'Connected';
    } catch (error) {
      this.status = 'Connection failed';
      console.error(`VPN Direct: start failed ${JSON.stringify(error)}`);
    } finally {
      this.connecting = false;
    }
  }

  private async disconnect(): Promise<void> {
    if (this.connecting || this.status === 'Disconnected') return;
    this.connecting = true;
    this.status = 'Disconnecting';
    try {
      await vpnExtension.stopVpnExtensionAbility(this.vpnWant());
      this.status = 'Disconnected';
    } catch (error) {
      this.status = 'Disconnect failed';
      console.error(`VPN Direct: stop failed ${JSON.stringify(error)}`);
    } finally {
      this.connecting = false;
    }
  }

  build() {
    AppShell({
      status: this.status,
      serverName: this.serverName,
      onToggle: () => {
        if (this.status === 'Connected') this.disconnect();
        else this.connect();
      },
      onServerTap: () => {
        this.serverName = this.serverName === 'Авто' ? 'Германия · Frankfurt' : 'Авто';
      }
    });
  }
}
