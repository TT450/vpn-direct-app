import { DirectTheme, DirectTypography, DirectSpacing } from '../ui/Theme';

@Component
export struct PlansPage {
  private readonly periods: string[] = ['1 месяц', '3 месяца', '6 месяцев', '12 месяцев'];
  @State private selected: number = 0;

  build() {
    Column() {
      Text('Тарифы').fontSize(DirectTypography.title).fontWeight(FontWeight.Bold).fontColor(DirectTheme.textPrimary)
        .width('100%').margin({ bottom: DirectSpacing.lg });
      Text('Выберите срок сервиса').fontSize(DirectTypography.secondary).fontColor(DirectTheme.textSecondary)
        .width('100%').margin({ bottom: DirectSpacing.lg });
      ForEach(this.periods, (period: string, index: number) => {
        Row() {
          Text(period).fontSize(DirectTypography.body).fontColor(DirectTheme.textPrimary);
          Blank();
          Text(index === 0 ? '249 ₽' : index === 1 ? '699 ₽' : index === 2 ? '1 399 ₽' : '2 599 ₽')
            .fontSize(DirectTypography.body).fontWeight(FontWeight.Bold).fontColor(DirectTheme.textPrimary);
        }.width('100%').height(60).padding({ left: 16, right: 16 }).backgroundColor(this.selected === index ? DirectTheme.surfaceElevated : DirectTheme.surface)
          .borderRadius(DirectTheme.radiusMedium).margin({ bottom: 10 }).onClick(() => this.selected = index);
      });
      Blank();
      Button('Продолжить').width('100%').height(DirectTheme.controlHeight).fontSize(DirectTypography.body)
        .fontWeight(FontWeight.Bold).backgroundColor(DirectTheme.textPrimary).fontColor(DirectTheme.background)
        .borderRadius(DirectTheme.radiusMedium);
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: 24, bottom: 24 }).backgroundColor(DirectTheme.background);
  }
}
