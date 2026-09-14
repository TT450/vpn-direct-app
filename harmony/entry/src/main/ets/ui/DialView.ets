import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics, DirectHapticEvent } from './Haptics';

/**
 * Pixel port of ApplicationLibrary/Views/DirectUI/DialView.swift.
 * Geometry is kept in the iOS coordinate system: 264×290 frame, 180×180
 * inner control, 2pt ring and 3×26pt needle.
 */
const RING_SEGMENT_COUNT: number = 192;
const RING_SEGMENT_INDICES: number[] = (() => {
  const indices: number[] = [];
  for (let i = 0; i < RING_SEGMENT_COUNT; i++) indices.push(i);
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
  private readonly ringSpan: number = (0.915 - 0.085) * Math.PI * 2;

  private ringColor(): string { return this.isConnected ? DirectTheme.ink : '#CED1CA'; }
  private ringRadius(): number { return (this.outer / 2) - 1; }
  private ringSegmentLength(): number { return ((this.ringSpan * this.ringRadius()) / RING_SEGMENT_COUNT) * 1.55; }
  private ringSegmentAngle(index: number): number { return this.ringGapEnd * Math.PI * 2 + (this.ringSpan * (index + 0.5)) / RING_SEGMENT_COUNT; }
  private ringSegmentDx(index: number): number { return this.ringRadius() * Math.cos(this.ringSegmentAngle(index)); }
  private ringSegmentDy(index: number): number { return this.ringRadius() * Math.sin(this.ringSegmentAngle(index)); }
  private ringSegmentRotate(index: number): number { return (this.ringSegmentAngle(index) * 180) / Math.PI + 90; }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Center }) {
        ForEach(RING_SEGMENT_INDICES, (index: number) => {
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
        // iOS: black opacity 0.20, radius 18, y 9. ArkUI's Circle shadow is
        // rectangular on some NEXT builds, so keep a soft precomposited layer.
        Circle().width(this.inner - 8).height(this.inner - 8).fill('#28000000').offset({ x: 0, y: 14 });
        Circle().width(this.inner).height(this.inner).fill(DirectTheme.ink).stroke('#E6478CFA').strokeWidth(0.5);

        Column({ space: 5 }) {
          Text('A / 01').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor('#7AFFFFFF').fontFamily('monospace');
          Text(this.isBusy ? '•••' : (this.isConnected ? 'ON' : 'OFF'))
            .fontSize(DirectTypography.display)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isConnected ? DirectTheme.acid : DirectTheme.dialOff)
            .fontFamily('sans-serif');
          if (this.isConnected) {
            Text('Нажмите, чтобы отключить').fontSize(9).fontWeight(FontWeight.Medium).fontColor('#80FFFFFF');
          } else {
            Column({ space: 1 }) {
              Text('Нажмите, чтобы').fontSize(9).fontWeight(FontWeight.Medium).fontColor('#80FFFFFF');
              Text('подключить').fontSize(9).fontWeight(FontWeight.Medium).fontColor('#80FFFFFF');
            }
          }
        }

        Column()
          .width(3).height(26).borderRadius(1.5)
          .backgroundColor(this.isConnected ? DirectTheme.acid : '#8CFFFFFF')
          .offset({ x: 0, y: -78 })
          .rotate({ angle: this.isConnected ? 132 : -132, centerX: '50%', centerY: '50%' })
          .animation({ duration: 550, curve: Curve.EaseInOut }, this.isConnected);
      }
      .width(this.inner)
      .height(this.inner);

      Text('OFF').fontSize(9).fontWeight(this.isConnected ? FontWeight.Medium : FontWeight.Bold).fontColor(this.isConnected ? DirectTheme.muted : DirectTheme.ink).fontFamily('monospace').offset({ x: -58, y: 146 });
      Text('ON').fontSize(9).fontWeight(this.isConnected ? FontWeight.Bold : FontWeight.Medium).fontColor(this.isConnected ? DirectTheme.ink : DirectTheme.muted).fontFamily('monospace').offset({ x: 58, y: 146 });
    }
    .width(this.outer)
    .height(this.frameH)
    .onClick(() => {
      DirectHaptics.play(this.isConnected ? DirectHapticEvent.ToggleOff : DirectHapticEvent.ToggleOn);
      this.onAction();
    });
  }
}
