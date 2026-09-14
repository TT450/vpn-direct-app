import { DirectTheme, DirectTypography, DirectSpacing } from '../ui/Theme';

@Component
export struct LocationsPage {
  @State private search: string = '';
  private readonly locations: string[] = ['Авто', 'Германия · Frankfurt', 'Нидерланды · Amsterdam', 'Испания · Madrid', 'Армения · Yerevan'];

  build() {
    Column() {
      Text('Локации').fontSize(DirectTypography.title).fontWeight(FontWeight.Bold).fontColor(DirectTheme.textPrimary)
        .width('100%').margin({ bottom: DirectSpacing.lg });
      Search({ placeholder: 'Поиск страны или города' })
        .value(this.search)
        .onChange((value: string) => this.search = value)
        .width('100%').height(48).margin({ bottom: DirectSpacing.lg });
      List() {
        ForEach(this.locations.filter((item: string) => item.toLowerCase().includes(this.search.toLowerCase())), (item: string, index: number) => {
          ListItem() {
            Row() {
              Text(index === 0 ? 'A' : '•').fontSize(16).fontWeight(FontWeight.Bold).fontColor(DirectTheme.textPrimary)
                .width(36).height(36).textAlign(TextAlign.Center).backgroundColor(DirectTheme.surfaceElevated).borderRadius(18);
              Text(item).fontSize(DirectTypography.body).fontColor(DirectTheme.textPrimary).margin({ left: 12 });
              Blank();
              Text('›').fontSize(20).fontColor(DirectTheme.textSecondary);
            }.width('100%').padding({ top: 14, bottom: 14 });
          }
        });
      }.width('100%').layoutWeight(1);
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: 24, bottom: 24 }).backgroundColor(DirectTheme.background);
  }
}
