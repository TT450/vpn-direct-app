import { DirectTheme } from './Theme';

export enum DirectIconName {
  ArrowClockwise = 'arrow.clockwise', ArrowLeftArrowRight = 'arrow.left.arrow.right', LocationNorth = 'location.north', Minus = 'minus', ArrowUpRight = 'arrow.up.right', ChevronRight = 'chevron.right', Menu = 'line.3.horizontal', ArrowLeft = 'arrow.left', Magnifyingglass = 'magnifyingglass', Xmark = 'xmark', Plus = 'plus', Checkmark = 'checkmark', ArrowRight = 'arrow.right', Star = 'star', Shield = 'shield', Connection = 'connection', Waveform = 'waveform', SlidersHorizontal = 'slider.horizontal.3'
}

@Component
export struct DirectIcon {
  @Prop name: string = DirectIconName.ChevronRight;
  @Prop iconSize: number = 12;
  @Prop color: string = DirectTheme.ink;
  @Prop weight: number = 1.5;
  private bar(): number { return Math.max(1.2, this.weight); }
  @Builder private svgIcon(res: Resource) { Image(res).width(this.iconSize).height(this.iconSize).objectFit(ImageFit.Contain).interpolation(ImageInterpolation.High); }
  build() {
    if (this.name === DirectIconName.Menu) this.svgIcon($r('app.media.ic_menu'));
    else if (this.name === DirectIconName.ArrowUpRight) this.svgIcon(this.color === DirectTheme.acid ? $r('app.media.ic_arrow_up_right_acid') : $r('app.media.ic_arrow_up_right'));
    else if (this.name === DirectIconName.ArrowLeft) this.svgIcon(this.color === DirectTheme.muted ? $r('app.media.ic_arrow_left_muted') : $r('app.media.ic_arrow_left'));
    else if (this.name === DirectIconName.Magnifyingglass) this.svgIcon($r('app.media.ic_magnifyingglass'));
    else if (this.name === DirectIconName.ChevronRight) this.svgIcon(this.color === DirectTheme.green ? $r('app.media.ic_chevron_right_green') : $r('app.media.ic_chevron_right'));
    else if (this.name === DirectIconName.Xmark) this.svgIcon(this.color === DirectTheme.acid ? $r('app.media.ic_xmark_acid') : $r('app.media.ic_xmark'));
    else if (this.name === DirectIconName.Star) this.svgIcon(this.color === DirectTheme.green ? $r('app.media.ic_star_green') : $r('app.media.ic_star'));
    else if (this.name === DirectIconName.Shield) {
      Stack({ alignContent: Alignment.Center }) {
        Shape() { Path().commands('M 8 1 L 13 3 V 7 C 13 10 11 12 8 15 C 5 12 3 10 3 7 V 3 Z').fill(Color.Transparent).stroke(this.color, this.bar()); }
      }.width(this.iconSize).height(this.iconSize);
    } else if (this.name === DirectIconName.Connection) {
      Stack({ alignContent: Alignment.Center }) {
        Circle().width(this.iconSize * 0.28).height(this.iconSize * 0.28).fill(this.color).offset({ x: -this.iconSize * 0.25 });
        Circle().width(this.iconSize * 0.28).height(this.iconSize * 0.28).fill(this.color).offset({ x: this.iconSize * 0.25 });
        Row().width(this.iconSize * 0.58).height(this.bar()).backgroundColor(this.color);
        Row().width(this.iconSize * 0.38).height(this.bar()).backgroundColor(this.color).rotate({ angle: 45 }).offset({ y: -this.iconSize * 0.22 });
        Row().width(this.iconSize * 0.38).height(this.bar()).backgroundColor(this.color).rotate({ angle: -45 }).offset({ y: this.iconSize * 0.22 });
      }.width(this.iconSize).height(this.iconSize);
    } else if (this.name === DirectIconName.Waveform) {
      Row({ space: this.iconSize * 0.05 }) {
        ForEach([0.30, 0.55, 0.85, 0.48, 0.72, 0.35], (h: number) => Column().width(Math.max(1.2, this.bar() * 0.8)).height(this.iconSize * h).backgroundColor(this.color));
      }.width(this.iconSize).height(this.iconSize).justifyContent(FlexAlign.Center);
    } else if (this.name === DirectIconName.SlidersHorizontal) {
      Column({ space: this.iconSize * 0.22 }) {
        this.slider(0.28); this.slider(0.68); this.slider(0.42);
      }.width(this.iconSize).height(this.iconSize).justifyContent(FlexAlign.Center);
    } else if (this.name === DirectIconName.Minus) Row().width(this.iconSize).height(this.bar()).backgroundColor(this.color).alignSelf(ItemAlign.Center);
    else if (this.name === DirectIconName.Plus) Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize).height(this.bar()).backgroundColor(this.color); Column().width(this.bar()).height(this.iconSize).backgroundColor(this.color); }.width(this.iconSize).height(this.iconSize);
    else if (this.name === DirectIconName.ArrowRight) Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize).height(this.bar()).backgroundColor(this.color); Row().width(this.iconSize * 0.45).height(this.bar()).backgroundColor(this.color).rotate({ angle: 40 }).offset({ x: this.iconSize * 0.22, y: -this.iconSize * 0.14 }); Row().width(this.iconSize * 0.45).height(this.bar()).backgroundColor(this.color).rotate({ angle: -40 }).offset({ x: this.iconSize * 0.22, y: this.iconSize * 0.14 }); }.width(this.iconSize).height(this.iconSize);
    else if (this.name === DirectIconName.ArrowLeftArrowRight) Column({ space: this.iconSize * 0.28 }) { Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize * 0.72).height(this.bar()).backgroundColor(this.color); Row().width(this.iconSize * 0.32).height(this.bar()).backgroundColor(this.color).rotate({ angle: -40 }).offset({ x: -this.iconSize * 0.18, y: -this.iconSize * 0.1 }); Row().width(this.iconSize * 0.32).height(this.bar()).backgroundColor(this.color).rotate({ angle: 40 }).offset({ x: -this.iconSize * 0.18, y: this.iconSize * 0.1 }); }.width(this.iconSize).height(this.iconSize * 0.36); Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize * 0.72).height(this.bar()).backgroundColor(this.color); Row().width(this.iconSize * 0.32).height(this.bar()).backgroundColor(this.color).rotate({ angle: 40 }).offset({ x: this.iconSize * 0.18, y: -this.iconSize * 0.1 }); Row().width(this.iconSize * 0.32).height(this.bar()).backgroundColor(this.color).rotate({ angle: -40 }).offset({ x: this.iconSize * 0.18, y: this.iconSize * 0.1 }); }.width(this.iconSize).height(this.iconSize * 0.36); }.width(this.iconSize).height(this.iconSize).justifyContent(FlexAlign.Center);
    else if (this.name === DirectIconName.ArrowClockwise) Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize * 0.72).height(this.iconSize * 0.72).border({ width: this.bar(), color: this.color }).borderRadius(this.iconSize * 0.36).backgroundColor(Color.Transparent); Row().width(this.iconSize * 0.34).height(this.bar()).backgroundColor(this.color).rotate({ angle: -35 }).offset({ x: this.iconSize * 0.18, y: -this.iconSize * 0.28 }); }.width(this.iconSize).height(this.iconSize);
    else if (this.name === DirectIconName.LocationNorth) Stack({ alignContent: Alignment.Center }) { Column().width(0).height(0).border({ width: { bottom: this.iconSize * 0.72, left: this.iconSize * 0.36, right: this.iconSize * 0.36 }, color: { bottom: this.color, left: Color.Transparent, right: Color.Transparent } }); }.width(this.iconSize).height(this.iconSize);
    else if (this.name === DirectIconName.Checkmark) Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize * 0.38).height(this.bar()).backgroundColor(this.color).rotate({ angle: 45 }).offset({ x: -this.iconSize * 0.12, y: this.iconSize * 0.06 }); Row().width(this.iconSize * 0.72).height(this.bar()).backgroundColor(this.color).rotate({ angle: -45 }).offset({ x: this.iconSize * 0.08, y: 0 }); }.width(this.iconSize).height(this.iconSize);
    else this.svgIcon($r('app.media.ic_chevron_right'));
  }
  @Builder private slider(position: number) {
    Stack({ alignContent: Alignment.Start }) {
      Row().width(this.iconSize).height(this.bar()).backgroundColor(this.color);
      Circle().width(this.bar() * 2.4).height(this.bar() * 2.4).fill(this.color).offset({ x: this.iconSize * position - this.bar() * 1.2 });
    }.width(this.iconSize).height(this.bar() * 3);
  }
}
