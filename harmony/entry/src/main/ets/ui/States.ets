import { DirectTheme, DirectTypography } from './Theme';

@Component
export struct DirectStatusBadge {
  @Prop label: string;
  @Prop tone: string;

  build() {
    Row() {
      Circle()
        .width(7)
        .height(7)
        .fill(this.tone)
        .margin({ right: 7 });
      Text(this.label)
        .fontSize(DirectTypography.caption)
        .fontWeight(FontWeight.Medium)
        .fontColor(DirectTheme.textPrimary);
    }
    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
    .backgroundColor(DirectTheme.surfaceElevated)
    .borderRadius(DirectTheme.radiusSmall);
  }
}

@Component
export struct DirectEmptyState {
  @Prop title: string;
  @Prop message: string;

  build() {
    Column() {
      Text(this.title)
        .fontSize(DirectTypography.headline)
        .fontWeight(FontWeight.Medium)
        .fontColor(DirectTheme.textPrimary);
      Text(this.message)
        .fontSize(DirectTypography.secondary)
        .fontColor(DirectTheme.textSecondary)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 });
    }
    .width('100%')
    .padding(32);
  }
}

@Component
export struct DirectErrorState {
  @Prop title: string;
  @Prop message: string;
  @Prop actionTitle: string;
  private onAction: () => void = () => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize(DirectTypography.headline)
        .fontWeight(FontWeight.Medium)
        .fontColor(DirectTheme.textPrimary);
      Text(this.message)
        .fontSize(DirectTypography.secondary)
        .fontColor(DirectTheme.textSecondary)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 });
      Button(this.actionTitle)
        .margin({ top: 20 })
        .onClick(() => this.onAction());
    }
    .width('100%')
    .padding(32);
  }
}
