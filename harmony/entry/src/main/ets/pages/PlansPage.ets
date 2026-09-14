import { DirectTheme, DirectTypography } from '../ui/Theme';

@Component
export struct PlansPage {
  private readonly periods: string[] = ['1 МЕСЯЦ', '3 МЕСЯЦА', '6 МЕСЯЦЕВ', '12 МЕСЯЦЕВ'];
  private readonly prices: string[] = ['249 ₽', '699 ₽', '1 399 ₽', '2 599 ₽'];
  @State private selected: number = 0;

  build() {
    Column() {
      Text('DIRECT / PLANS').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
      Text('Тарифы').fontSize(DirectTypography.pageTitle).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%').margin({ top: 7 });
      Text('Выберите срок сервиса').fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ top: 4, bottom: 16 });

      ForEach(this.periods, (period: string, index: number) => {
        Row() {
          Text(String(index + 1).padStart(2, '0')).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width(22);
          Rectangle().width(3).height(14).fill(index === this.selected ? DirectTheme.acid : DirectTheme.line).margin({ right: 10 });
          Text(period).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).fontFamily('monospace');
          Blank();
          Text(this.prices[index]).fontSize(13).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
        }.width('100%').height(58).padding({ left: 12, right: 12 }).backgroundColor(index === this.selected ? DirectTheme.paper : DirectTheme.paper)
          .border({ width: { top: 1, bottom: 1 }, color: index === this.selected ? DirectTheme.ink : DirectTheme.line })
          .onClick(() => this.selected = index);
      });

      Blank();
      Button('ПРОДОЛЖИТЬ').width('100%').height(47).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid)
        .backgroundColor(DirectTheme.ink);
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 24 }).backgroundColor(DirectTheme.paper);
  }
}
