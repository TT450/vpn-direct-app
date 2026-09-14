import { DirectTheme, DirectTypography } from '../ui/Theme';

@Component
export struct LocationsPage {
  @State private search: string = '';
  private readonly locations: string[] = ['Авто', 'Германия · Frankfurt', 'Нидерланды · Amsterdam', 'Финляндия · Helsinki', 'Швеция · Stockholm', 'Армения · Yerevan'];

  build() {
    Column() {
      Row() {
        Column() {
          Text('DIRECT / LOCATIONS').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Text('Локации').fontSize(DirectTypography.pageTitle).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 7 });
          Text('6 локаций · витрина').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 4 });
        }.alignItems(HorizontalAlign.Start);
        Blank();
        Text('↻').fontSize(18).fontColor(DirectTheme.ink).width(36).height(36).textAlign(TextAlign.Center).border({ width: 1, color: DirectTheme.line });
      }.width('100%').margin({ bottom: 16 });

      Row() {
        Text('⌕').fontSize(18).fontColor(DirectTheme.muted).margin({ right: 8 });
        Search({ placeholder: 'Страна или город' }).value(this.search).onChange((value: string) => this.search = value)
          .fontSize(11).fontColor(DirectTheme.ink).fontFamily('monospace').layoutWeight(1).height(43);
      }.width('100%').height(43).padding({ left: 12, right: 12 }).border({ width: 1, color: DirectTheme.line }).margin({ bottom: 14 });

      List() {
        ForEach(this.locations.filter((item: string) => item.toLowerCase().includes(this.search.toLowerCase())), (item: string, index: number) => {
          ListItem() {
            Row() {
              Text(index === 0 ? 'A' : item.substring(0, 2).toUpperCase())
                .fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace')
                .width(36).height(28).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink);
              Column() {
                Text(item).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink);
                Text(index === 0 ? 'Автовыбор маршрута' : '— MS').fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 3 });
              }.alignItems(HorizontalAlign.Start).margin({ left: 11 });
              Blank();
              Text('›').fontSize(14).fontColor(DirectTheme.muted);
            }.width('100%').height(58).padding({ left: 12, right: 12 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
          }
        });
      }.width('100%').layoutWeight(1);
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 0 }).backgroundColor(DirectTheme.paper);
  }
}
