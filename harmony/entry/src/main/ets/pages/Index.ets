import { common } from '@kit.AbilityKit';
import { vpnExtension } from '@kit.NetworkKit';

@Entry
@Component
struct Index {
  @State private status: string = 'Disconnected';
  @State private connecting: boolean = false;
  private readonly bundleName: string = 'com.vpndirect.vpndirectapp';
  private readonly extensionName: string = 'VpnDirectVpnExtension';

  private vpnWant(): common.StartOptions {
    return {
      want: {
        deviceId: '',
        bundleName: this.bundleName,
        abilityName: this.extensionName,
        parameters: {
          profileJson: JSON.stringify({
            address: '172.19.0.2',
            dns: '1.1.1.1',
            mtu: 1400,
            ipv6: true
          })
        }
      }
    };
  }

  private async connect(): Promise<void> {
    if (this.connecting || this.status === 'Connected') {
      return;
    }
    this.connecting = true;
    this.status = 'Connecting';
    try {
      await vpnExtension.startVpnExtensionAbility(this.vpnWant().want);
      this.status = 'Connected';
    } catch (error) {
      this.status = 'Connection failed';
      console.error(`VPN Direct: start failed ${JSON.stringify(error)}`);
    } finally {
      this.connecting = false;
    }
  }

  private async disconnect(): Promise<void> {
    if (this.connecting || this.status === 'Disconnected') {
      return;
    }
    this.connecting = true;
    this.status = 'Disconnecting';
    try {
      await vpnExtension.stopVpnExtensionAbility(this.vpnWant().want);
      this.status = 'Disconnected';
    } catch (error) {
      this.status = 'Disconnect failed';
      console.error(`VPN Direct: stop failed ${JSON.stringify(error)}`);
    } finally {
      this.connecting = false;
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('VPN Direct')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
          Text('HarmonyOS NEXT')
            .fontSize(13)
            .opacity(0.55)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('Core 0.1.0')
          .fontSize(12)
          .opacity(0.45)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 12 })

      Blank()

      Column() {
        Stack() {
          Circle()
            .width(188)
            .height(188)
            .fill('#101826')

          Circle()
            .width(164)
            .height(164)
            .fill('#172338')

          Text(this.status === 'Connected' ? 'ON' : 'OFF')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
        }
        .onClick(() => {
          if (this.status === 'Connected') {
            this.disconnect();
          } else {
            this.connect();
          }
        })

        Text(this.status)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 24 })

        Text('VPN Direct Core · sing-box-lx')
          .fontSize(12)
          .opacity(0.45)
          .margin({ top: 8 })
      }

      Blank()

      Column() {
        Row() {
          Text('Server')
            .fontSize(13)
            .opacity(0.55)
          Blank()
          Text('Germany · Frankfurt')
            .fontSize(14)
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#101826')
        .borderRadius(16)
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#070B12')
    .fontColor('#FFFFFF')
  }
}
