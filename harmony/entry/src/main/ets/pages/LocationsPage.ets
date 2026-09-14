import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics } from '../ui/Haptics';

interface LocationItem {
  code: string;
  country: string;
  city: string;
  latency: string;
  quality: string;
}

@Component
export struct LocationsPage {
  @State private search: string = '';
  @State private selected: string = 'Авто';

  private readonly locations: LocationItem[] = [
    { code: 'A', country: 'Авто', city: 'Автовыбор маршрута', latency: '— MS', quality: 'ОПТИМАЛЬНО' },
    { code: 'DE', country: 'Германия', city: 'Frankfurt', latency: '— MS', quality: 'СТАБИЛЬНО' },
    { code: 'NL', country: 'Нидерланды', city: 'Amsterdam', latency: '— MS', quality: 'СТАБИЛЬНО' },
    { code: 'FI', country: 'Финляндия', city: 'Helsinki', latency: '— MS', quality: 'СТАБИЛЬНО' },
    { code: 'SE', country: 'Швеция', city: 'Stockholm', latency: '— MS', quality: 'СТАБИЛЬНО' },
    { code: 'AM', country: 'Армения', city: 'Yerevan', latency: '— MS', quality: 'СТАБИЛЬНО' }
  ];

  private filtered(): LocationItem[] {
    const q = this.search.trim().toLowerCase();
    if (q.length === 0) return this.locations;
    return this.locations.filter((item: LocationItem) =>
      item.country.toLowerCase().includes(q) || item.city.toLowerCase().includes(q) || item.code.toLowerCase().includes(q)
    );
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('DIRECT / LOCATIONS').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Text('Локации').fontSize(DirectTypography.pageTitle).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 7 });
          Text('6 локаций · витрина').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 4 });
        }.alignItems(HorizontalAlign.Start);
        Blank();
        Text('↻').fontSize(18).fontColor(DirectTheme.ink).width(36).height(36).textAlign(TextAlign.Center)
          .border({ width: 1, color: DirectTheme.line }).onClick(() => DirectHaptics.navigation());
      }.width('100%').margin({ bottom: 16 });

      Row() {
        Text('⌕').fontSize(18).fontColor(DirectTheme.muted).margin({ right: 8 });
        Search({ placeholder: 'Страна или город' }).value(this.search).onChange((value: string) => this.search = value)
          .fontSize(11).fontColor(DirectTheme.ink).fontFamily('monospace').layoutWeight(1).height(43);
      }.width('100%').height(43).padding({ left: 12, right: 12 }).border({ width: 1, color: DirectTheme.line }).margin({ bottom: 14 });

      Row() {
        this.accessCard('ТАРИФЫ', 'Готовые планы', 'START · PLUS · PRO', false);
        this.accessCard('КОНСТРУКТОР', 'Собрать свой', 'ДНИ · УСТРОЙСТВА · ТРАФИК', true);
      }.width('100%').margin({ bottom: 14 });

      List() {
        ForEach(this.filtered(), (item: LocationItem, index: number) => {
          ListItem() {
            Row() {
              Text(item.code).fontSize(item.code === 'A' ? 12 : 8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace')
                .width(36).height(item.code === 'A' ? 28 : 20).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink);
              Column() {
                Row() {
                  Text(item.code === 'A' ? 'АВТО' : 'СЕРВЕР').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
                  Text('·').fontSize(DirectTypography.caption).fontColor(DirectTheme.muted).margin({ left: 4, right: 4 });
                  Text(item.country.toUpperCase()).fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
                }
                Text(item.city).fontSize(14).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).margin({ top: 2 });
              }.alignItems(HorizontalAlign.Start).margin({ left: 10 });
              Blank();
              Column() {
                Row() {
                  Circle().width(5).height(5).fill(DirectTheme.green).margin({ right: 4 });
                  Text(item.latency).fontSize(DirectTypography.caption).fontColor(DirectTheme.ink).fontFamily('monospace');
                }
                Text(this.selected === item.country ? '✓' : '›').fontSize(12).fontColor(DirectTheme.muted);
              }.alignItems(HorizontalAlign.End);
            }.width('100%').height(58).padding({ left: 0, right: 0 })
              .border({ width: { bottom: 1 }, color: DirectTheme.line })
              .onClick(() => { this.selected = item.country; DirectHaptics.selection(); });
          }
        });
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off);
    }.width('100%').height('100%').padding({ left: DirectTheme.pageHorizontal, right: DirectTheme.pageHorizontal, top: DirectTheme.pageTop, bottom: 0 }).backgroundColor(DirectTheme.paper);
  }

  @Builder
  private accessCard(kicker: string, title: string, detail: string, primary: boolean) {
    Column() {
      Row() {
        Text(kicker).fontSize(8).fontWeight(FontWeight.Bold).fontColor(primary ? DirectTheme.acid : DirectTheme.ink).fontFamily('monospace');
        Blank();
        Text('↗').fontSize(9).fontColor(primary ? DirectTheme.acid : DirectTheme.muted);
      }
      Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(primary ? DirectTheme.paper : DirectTheme.ink).margin({ top: 5 });
      Text(detail).fontSize(8).fontWeight(FontWeight.Medium).fontColor(primary ? '#94FFFFFF' : DirectTheme.muted).fontFamily('monospace').margin({ top: 5 });
    }.layoutWeight(1).minHeight(70).padding(10).margin({ right: primary ? 0 : 8 })
      .backgroundColor(primary ? DirectTheme.ink : DirectTheme.paper)
      .border({ width: primary ? 1.5 : 1, color: primary ? DirectTheme.ink : DirectTheme.line });
  }
}
