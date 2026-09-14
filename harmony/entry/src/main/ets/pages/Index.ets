@Entry
@Component
struct Index {
  @State private status: string = 'Disconnected';
  @State private connected: boolean = false;

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

        Text('0.1.0')
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

          Text(connected ? 'ON' : 'OFF')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
        }
        .onClick(() => {
          this.connected = !this.connected;
          this.status = this.connected ? 'Connected' : 'Disconnected';
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
