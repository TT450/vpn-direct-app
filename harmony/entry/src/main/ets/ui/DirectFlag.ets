import { DirectTheme } from './Theme';

/** Native geometric flags — no emoji, deterministic rendering on HarmonyOS. */
@Component
export struct DirectFlag {
  @Prop code: string = '';
  @Prop width: number = 31;
  @Prop height: number = 21;

  private normalized(): string { return this.code.trim().toUpperCase(); }

  @Builder private stripes(colors: string[], horizontal: boolean = true) {
    if (horizontal) {
      Column() { ForEach(colors, (c: string) => Row().width('100%').height(this.height / colors.length).backgroundColor(c)); }.width('100%').height('100%');
    } else {
      Row() { ForEach(colors, (c: string) => Column().height('100%').width(this.width / colors.length).backgroundColor(c)); }.width('100%').height('100%');
    }
  }

  @Builder private flagBody() {
    const c = this.normalized();
    if (c === 'DE') this.stripes(['#141414', '#DD0000', '#FFCE00']);
    else if (c === 'NL') this.stripes(['#AE1C28', '#FFFFFF', '#21468B']);
    else if (c === 'FR') this.stripes(['#0055A4', '#FFFFFF', '#EF4135'], false);
    else if (c === 'IT') this.stripes(['#009246', '#FFFFFF', '#CE2B37'], false);
    else if (c === 'IE') this.stripes(['#169B62', '#FFFFFF', '#FF883E'], false);
    else if (c === 'BE') this.stripes(['#000000', '#FDD835', '#EF3340'], false);
    else if (c === 'ES') Column() { Row().width('100%').height(this.height * 0.25).backgroundColor('#AA151B'); Row().width('100%').height(this.height * 0.5).backgroundColor('#F1BF00'); Row().width('100%').height(this.height * 0.25).backgroundColor('#AA151B'); }.width('100%').height('100%');
    else if (c === 'GB') Stack() { Row().width('100%').height('100%').backgroundColor('#012169'); Row().width('100%').height(3).backgroundColor('#FFFFFF').rotate({ angle: 45 }); Row().width('100%').height(3).backgroundColor('#FFFFFF').rotate({ angle: -45 }); Row().width('100%').height(5).backgroundColor('#C8102E'); Column().width(5).height('100%').backgroundColor('#C8102E'); }.width('100%').height('100%');
    else if (c === 'US') Stack() { Column() { ForEach(Array.from({ length: 13 }, (_: number, i: number) => Row().width('100%').height(this.height / 13).backgroundColor(i % 2 === 0 ? '#B22234' : '#FFFFFF')); }.width('100%').height('100%'); Row().width(this.width * 0.45).height(this.height * 0.54).backgroundColor('#3C3B6E'); }.width('100%').height('100%');
    else if (c === 'TR') Stack() { Row().width('100%').height('100%').backgroundColor('#E30A17'); Text('★').fontSize(this.height * 0.62).fontColor('#FFFFFF'); }.width('100%').height('100%');
    else if (c === 'AZ') this.stripes(['#00B5E2', '#EF3340', '#509E2F']);
    else if (c === 'AM') this.stripes(['#D90012', '#0033A0', '#F2A800']);
    else if (c === 'RU') this.stripes(['#FFFFFF', '#0039A6', '#D52B1E']);
    else if (c === 'PL') this.stripes(['#FFFFFF', '#DC143C']);
    else if (c === 'FI') Stack() { Row().width('100%').height('100%').backgroundColor('#FFFFFF'); Row().width('100%').height(5).backgroundColor('#003580').offset({ y: -2 }); Column().width(5).height('100%').backgroundColor('#003580').offset({ x: -this.width * 0.12 }); }.width('100%').height('100%');
    else if (c === 'SE') Stack() { Row().width('100%').height('100%').backgroundColor('#006AA7'); Row().width('100%').height(4).backgroundColor('#FECC00').offset({ y: -2 }); Column().width(4).height('100%').backgroundColor('#FECC00').offset({ x: -this.width * 0.12 }); }.width('100%').height('100%');
    else if (c === 'CH') Stack() { Row().width('100%').height('100%').backgroundColor('#D52B1E'); Column().width(this.width * 0.58).height(4).backgroundColor('#FFFFFF'); Row().width(4).height(this.height * 0.58).backgroundColor('#FFFFFF'); }.width('100%').height('100%');
    else if (c === 'JP') Stack() { Row().width('100%').height('100%').backgroundColor('#FFFFFF'); Row().width(this.height * 0.52).height(this.height * 0.52).borderRadius(this.height * 0.26).backgroundColor('#BC002D'); }.width('100%').height('100%');
    else if (c === 'CA') Row() { Column().width(this.width * 0.25).height('100%').backgroundColor('#D80621'); Column().layoutWeight(1).height('100%').backgroundColor('#FFFFFF'); Column().width(this.width * 0.25).height('100%').backgroundColor('#D80621'); }.width('100%').height('100%');
    else Stack() { Row().width('100%').height('100%').backgroundColor(DirectTheme.ink); Text(c.length === 2 ? c : '—').fontSize(Math.max(7, this.height * 0.42)).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); }.width('100%').height('100%');
  }

  build() {
    Stack() { this.flagBody(); }.width(this.width).height(this.height).border({ width: 0.5, color: '#24000000' }).clip(true);
  }
}