import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics, DirectHapticEvent } from './Haptics';

/**
 * Pixel port of ApplicationLibrary/Views/DirectUI/DialView.swift
 *
 * ArkUI pitfalls on this emulator:
 * - Canvas / Path().width/height → opaque light plate behind dial
 * - Circle.shadow() → rectangular halo
 *
 * Ring = dense tangential segments (butt stroke 2) on trim 0.085→0.915.
 * Disconnected color = ink@14% precomposited on paper (#CED1CA), not alpha
 * (alpha on tiny Columns often paints invisible).
 */
const RING_SEGMENT_COUNT: number = 192;
// Pre-built index array — dense segments for a visually continuous ring
const RING_SEGMENT_INDICES: number[] = (() => {
  const indices: number[] = [];
  for (let i = 0; i < RING_SEGMENT_COUNT; i++) {
    indices.push(i);
  }
  return indices;
})();

@Component
export struct DialView {
  @Prop isConnected: boolean = false;
  @Prop isBusy: boolean = false;
  onAction: () => void = () => {};

  private readonly outer: number = DirectTheme.dialOuter;
  private readonly inner: number = DirectTheme.dialInner;
  private readonly frameH: number = DirectTheme.dialFrameHeight;
  private readonly ringGapEnd: number = 0.085;
  private readonly ringGapStart: number = 0.915;
  /** Circumference span for trim window */
  private readonly ringSpan: number = (0.915 - 0.085) * Math.PI * 2;

  private ringColor(): string {
    // Connected: solid ink. Off: ink 14% over paper (visible solid).
    return this.isConnected ? DirectTheme.ink : '#CED1CA';
  }

  /** Arc radius to stroke centerline */
  private ringRadius(): number {
    return (this.outer / 2) - 1;
  }

  /** Segment length along arc with overlap → continuous stroke */
  private ringSegmentLength(): number {
    const arcLen = this.ringSpan * this.ringRadius();
    return (arcLen / RING_SEGMENT_COUNT) * 1.55;
  }

  private ringSegmentAngle(index: number): number {
    return this.ringGapEnd * Math.PI * 2 + (this.ringSpan * (index + 0.5)) / RING_SEGMENT_COUNT;
  }

  private ringSegmentDx(index: number): number {
    return this.ringRadius() * Math.cos(this.ringSegmentAngle(index));
  }

  private ringSegmentDy(index: number): number {
    return this.ringRadius() * Math.sin(this.ringSegmentAngle(index));
  }

  /** Tangential orientation (horizontal bar → along circumference) */
  private ringSegmentRotate(index: number): number {
    return (this.ringSegmentAngle(index) * 180) / Math.PI + 90;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Center }) {
        ForEach(RING_SEGMENT_INDICES, (index: number) => {
          // Stroke segment: length along tangent × lineWidth 2 (Swift StrokeStyle lineWidth 2, butt)
          Row()
            .width(this.ringSegmentLength())
            .height(2)
            .backgroundColor(this.ringColor())
            .offset({ x: this.ringSegmentDx(index), y: this.ringSegmentDy(index) })
            .rotate({ angle: this.ringSegmentRotate(index), centerX: '50%', centerY: '50%' });
        }, (index: number) => `ring-${index}`);
      }
      .width(this.outer)
      .height(this.outer);

      Stack({ alignContent: Alignment.Center }) {
        // Soft drop without Circle.shadow() (that API paints a rectangular plate).
        // Slightly larger, lower, transparent disk — must not read as a second ring.
        Circle()
          .width(this.inner - 8)
          .height(this.inner - 8)
          .fill('#28000000')
          .offset({ x: 0, y: 14 });

        Circle()
          .width(this.inner)
          .height(this.inner)
          .fill(DirectTheme.ink)
          .stroke('#E6478CFA')
          .strokeWidth(0.5);

        Column({ space: 5 }) {
          Text('A / 01')
            .fontSize(DirectTypography.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor('#7AFFFFFF')
            .fontFamily('monospace');

          Text(this.isBusy ? '•••' : (this.isConnected ? 'ON' : 'OFF'))
            .fontSize(DirectTypography.display)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isConnected ? DirectTheme.acid : DirectTheme.dialOff);

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

        // Capsule needle — Swift 3×26 @ y−78, ±132°
        Column()
          .width(3)
          .height(26)
          .borderRadius(1.5)
          .backgroundColor(this.isConnected ? DirectTheme.acid : '#8CFFFFFF')
          .offset({ x: 0, y: -78 })
          .rotate({ angle: this.isConnected ? 132 : -132, centerX: '50%', centerY: '50%' });
      }
      .width(this.inner)
      .height(this.inner);

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
    }
      .width(this.outer)
      .height(this.frameH)
      .onClick(() => {
        DirectHaptics.play(this.isConnected ? DirectHapticEvent.ToggleOff : DirectHapticEvent.ToggleOn);
        this.onAction();
      });
  }
}
