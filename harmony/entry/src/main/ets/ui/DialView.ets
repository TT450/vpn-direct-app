import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics, DirectHapticEvent } from './Haptics';

@Component
export struct DialView {
  @Prop isConnected: boolean = false;
  @Prop isBusy: boolean = false;
  onAction: () => void = () => {};

  private readonly settings: RenderingContextSettings = new RenderingContextSettings(true);
  private readonly context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private readonly outer: number = DirectTheme.dialOuter;
  private readonly inner: number = DirectTheme.dialInner;
  private readonly frameH: number = DirectTheme.dialFrameHeight;
  private readonly ringStart: number = 0.085 * Math.PI * 2;
  private readonly ringSweep: number = 0.83 * Math.PI * 2;

  private drawRing(): void {
    this.context.clearRect(0, 0, this.outer, this.outer);
    this.context.beginPath();
    this.context.lineWidth = 2;
    this.context.strokeStyle = this.isConnected ? DirectTheme.ink : '#24000000';
    this.context.lineCap = 'butt';
    this.context.arc(this.outer / 2, this.outer / 2, (this.outer / 2) - 1, this.ringStart, this.ringStart + this.ringSweep, false);
    this.context.stroke();
  }

  private needleOffsetX(): number {
    return this.isConnected ? 58 : -58;
  }

  private needleAngle(): number {
    return this.isConnected ? 132 : -132;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Canvas(this.context)
        .width(this.outer)
        .height(this.outer)
        .onReady(() => this.drawRing());

      Text('OFF')
        .fontSize(9)
        .fontWeight(this.isConnected ? FontWeight.Medium : FontWeight.Bold)
        .fontColor(this.isConnected ? DirectTheme.muted : DirectTheme.ink)
        .fontFamily('monospace')
        .offset({ x: -58, y: 146 });

      Text('ON')
        .fontSize(9)
        .fontWeight(this.isConnected ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.isConnected ? DirectTheme.ink : DirectTheme.muted)
        .fontFamily('monospace')
        .offset({ x: 58, y: 146 });

      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(this.inner)
          .height(this.inner)
          .fill(DirectTheme.ink)
          .stroke('#E6478CFA')
          .strokeWidth(0.5)
          .shadow({ radius: 18, color: '#33000000', offsetX: 0, offsetY: 9 });

        Column({ space: 5 }) {
          Text('A / 01')
            .fontSize(DirectTypography.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor('#7AFFFFFF')
            .fontFamily('monospace');

          Text(this.isBusy ? '•••' : (this.isConnected ? 'ON' : 'OFF'))
            .fontSize(DirectTypography.display)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isConnected ? DirectTheme.acid : DirectTheme.dialOff)
            .fontFamily('sans-serif');

          if (this.isConnected) {
            Text('Нажмите, чтобы отключить')
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor('#80FFFFFF');
          } else {
            Column({ space: 1 }) {
              Text('Нажмите, чтобы')
                .fontSize(9)
                .fontWeight(FontWeight.Medium)
                .fontColor('#80FFFFFF');
              Text('подключить')
                .fontSize(9)
                .fontWeight(FontWeight.Medium)
                .fontColor('#80FFFFFF');
            }
          }
        }

        Column()
          .width(3)
          .height(26)
          .borderRadius(1.5)
          .backgroundColor(this.isConnected ? DirectTheme.acid : '#8CFFFFFF')
          .offset({ x: this.needleOffsetX(), y: 52.2 })
          .rotate({ angle: this.needleAngle(), centerX: '50%', centerY: '50%' })
          .animation({ duration: 550, curve: Curve.EaseInOut }, this.isConnected);
      }
      .width(this.inner)
      .height(this.inner)
      .onClick(() => {
        DirectHaptics.play(this.isConnected ? DirectHapticEvent.ToggleOff : DirectHapticEvent.ToggleOn);
        this.onAction();
      });
    }
    .width(this.outer)
    .height(this.frameH);
  }
}
