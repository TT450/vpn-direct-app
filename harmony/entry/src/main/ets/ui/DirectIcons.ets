import { DirectTheme } from './Theme';

export enum DirectIconName {
  ArrowClockwise = 'arrow.clockwise', ArrowLeftArrowRight = 'arrow.left.arrow.right', LocationNorth = 'location.north', Minus = 'minus', ArrowUpRight = 'arrow.up.right', ChevronRight = 'chevron.right', Menu = 'line.3.horizontal', ArrowLeft = 'arrow.left', Magnifyingglass = 'magnifyingglass', Xmark = 'xmark', Plus = 'plus', Checkmark = 'checkmark', ArrowRight = 'arrow.right', Star = 'star'
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
    else if (this.name === DirectIconName.ArrowUpRight) this.svgIcon($r('app.media.ic_arrow_up_right'));
    else if (this.name === DirectIconName.ArrowLeft) this.svgIcon($r('app.media.ic_arrow_left'));
    else if (this.name === DirectIconName.Magnifyingglass) this.svgIcon($r('app.media.ic_magnifyingglass'));
    else if (this.name === DirectIconName.ChevronRight) this.svgIcon(this.color === DirectTheme.green ? $r('app.media.ic_chevron_right_green') : $r('app.media.ic_chevron_right'));
    else if (this.name === DirectIconName.Xmark) this.svgIcon(this.color === DirectTheme.acid ? $r('app.media.ic_xmark_acid') : $r('app.media.ic_xmark'));
    else if (this.name === DirectIconName.Star) this.svgIcon($r('app.media.ic_star'));
    else if (this.name === DirectIconName.Minus) Row().width(this.iconSize).height(this.bar()).backgroundColor(this.color).alignSelf(ItemAlign.Center);
    else if (this.name === DirectIconName.Plus) Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize).height(this.bar()).backgroundColor(this.color); Column().width(this.bar()).height(this.iconSize).backgroundColor(this.color); }.width(this.iconSize).height(this.iconSize);
    else if (this.name === DirectIconName.ArrowRight) Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize).height(this.bar()).backgroundColor(this.color); Row().width(this.iconSize * 0.45).height(this.bar()).backgroundColor(this.color).rotate({ angle: 40 }).offset({ x: this.iconSize * 0.22, y: -this.iconSize * 0.14 }); Row().width(this.iconSize * 0.45).height(this.bar()).backgroundColor(this.color).rotate({ angle: -40 }).offset({ x: this.iconSize * 0.22, y: this.iconSize * 0.14 }); }.width(this.iconSize).height(this.iconSize);
    else if (this.name === DirectIconName.ArrowLeftArrowRight) Column({ space: this.iconSize * 0.28 }) { Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize * 0.72).height(this.bar()).backgroundColor(this.color); Row().width(this.iconSize * 0.32).height(this.bar()).backgroundColor(this.color).rotate({ angle: -40 }).offset({ x: -this.iconSize * 0.18, y: -this.iconSize * 0.1 }); Row().width(this.iconSize * 0.32).height(this.bar()).backgroundColor(this.color).rotate({ angle: 40 }).offset({ x: -this.iconSize * 0.18, y: this.iconSize * 0.1 }); }.width(this.iconSize).height(this.iconSize * 0.36); Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize * 0.72).height(this.bar()).backgroundColor(this.color); Row().width(this.iconSize * 0.32).height(this.bar()).backgroundColor(this.color).rotate({ angle: 40 }).offset({ x: this.iconSize * 0.18, y: -this.iconSize * 0.1 }); Row().width(this.iconSize * 0.32).height(this.bar()).backgroundColor(this.color).rotate({ angle: -40 }).offset({ x: this.iconSize * 0.18, y: this.iconSize * 0.1 }); }.width(this.iconSize).height(this.iconSize * 0.36); }.width(this.iconSize).height(this.iconSize).justifyContent(FlexAlign.Center);
    else if (this.name === DirectIconName.ArrowClockwise) Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize * 0.72).height(this.iconSize * 0.72).border({ width: this.bar(), color: this.color }).borderRadius(this.iconSize * 0.36).backgroundColor(Color.Transparent); Row().width(this.iconSize * 0.34).height(this.bar()).backgroundColor(this.color).rotate({ angle: -35 }).offset({ x: this.iconSize * 0.18, y: -this.iconSize * 0.28 }); }.width(this.iconSize).height(this.iconSize);
    else if (this.name === DirectIconName.LocationNorth) Stack({ alignContent: Alignment.Center }) { Column().width(0).height(0).border({ width: { bottom: this.iconSize * 0.72, left: this.iconSize * 0.36, right: this.iconSize * 0.36 }, color: { bottom: this.color, left: Color.Transparent, right: Color.Transparent } }); }.width(this.iconSize).height(this.iconSize);
    else if (this.name === DirectIconName.Checkmark) Stack({ alignContent: Alignment.Center }) { Row().width(this.iconSize * 0.38).height(this.bar()).backgroundColor(this.color).rotate({ angle: 45 }).offset({ x: -this.iconSize * 0.12, y: this.iconSize * 0.06 }); Row().width(this.iconSize * 0.72).height(this.bar()).backgroundColor(this.color).rotate({ angle: -45 }).offset({ x: this.iconSize * 0.08, y: 0 }); }.width(this.iconSize).height(this.iconSize);
    else this.svgIcon($r('app.media.ic_chevron_right'));
  }
}
