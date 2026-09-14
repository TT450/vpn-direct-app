import { DirectTheme, DirectTypography, DirectSpacing } from '../ui/Theme';

@Component
export struct HomePage {
  @Prop status: string = 'Disconnected';
  @Prop serverName: string = 'Auto';
  private onToggle: () => void = () => {};
  private onServerTap: () => void = () => {};

  build() {
    Column() {
      Row() {
        Column() {
          Text('VPN Direct')
            .fontSize(DirectTypography.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.textPrimary);
          Text('Private connection')
            .fontSize(DirectTypography.caption)
            .fontColor(DirectTheme.textSecondary)
            .margin({ top: 4 });
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Text(this.status)
          .fontSize(DirectTypography.caption)
          .fontColor(DirectTheme.textSecondary);
      }
      .width('100%');

      Blank();

      Stack() {
        Circle()
          .width(220)
          .height(220)
          .fill(DirectTheme.surface);
        Circle()
          .width(192)
          .height(192)
          .fill(DirectTheme.surfaceElevated);
        Column() {
          Text(this.status === 'Connected' ? 'ON' : 'OFF')
            .fontSize(DirectTypography.display)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.textPrimary);
          Text(this.status === 'Connected' ? 'Protected' : 'Tap to connect')
            .fontSize(DirectTypography.secondary)
            .fontColor(DirectTheme.textSecondary)
            .margin({ top: 6 });
        }
      }
      .onClick(() => this.onToggle());

      Text(this.status === 'Connected' ? 'Connection active' : 'VPN is disconnected')
        .fontSize(DirectTypography.headline)
        .fontWeight(FontWeight.Medium)
        .fontColor(DirectTheme.textPrimary)
        .margin({ top: DirectSpacing.xl });

      Row() {
        Text('Server')
          .fontSize(DirectTypography.secondary)
          .fontColor(DirectTheme.textSecondary);
        Blank();
        Text(this.serverName)
          .fontSize(DirectTypography.secondary)
          .fontColor(DirectTheme.textPrimary);
        Text('›')
          .fontSize(22)
          .fontColor(DirectTheme.textSecondary)
          .margin({ left: 8 });
      }
      .width('100%')
      .padding(18)
      .backgroundColor(DirectTheme.surface)
      .borderRadius(DirectTheme.radiusMedium)
      .margin({ top: DirectSpacing.xxl })
      .onClick(() => this.onServerTap());

      Blank();

      Text('VPN Direct Core')
        .fontSize(DirectTypography.caption)
        .fontColor(DirectTheme.textTertiary);
    }
    .width('100%')
    .height('100%')
    .padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: 24, bottom: 24 })
    .backgroundColor(DirectTheme.background);
  }
}
