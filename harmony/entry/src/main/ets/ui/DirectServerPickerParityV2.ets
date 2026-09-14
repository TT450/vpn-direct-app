import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectBackendRuntime, DirectLocationRecord } from '../backend/DirectBackendRuntime';
import { VpnServerSelection } from '../vpn/VpnServerSelection';

const FAVORITES_KEY: string = 'direct_server_favorites';
const RECENT_KEY: string = 'direct_server_recent';

interface PickerLocation extends DirectLocationRecord {
  latency: number;
}

function readIds(key: string): string[] {
  const raw: string = AppStorage.get<string>(key) ?? '[]';
  try {
    const parsed = JSON.parse(raw) as Object;
    return Array.isArray(parsed) ? (parsed as string[]) : [];
  } catch {
    return [];
  }
}

function writeIds(key: string, ids: string[]): void {
  AppStorage.setOrCreate<string>(key, JSON.stringify(ids.slice(0, 20)));
}

@Component
export struct DirectServerPickerParityV2 {
  onClose: () => void = () => {};
  @State private selected: string = VpnServerSelection.get().id;
  @State private query: string = '';
  @State private tab: number = 0;
  @State private locations: PickerLocation[] = [];
  @State private favorites: string[] = readIds(FAVORITES_KEY);
  @State private recent: string[] = readIds(RECENT_KEY);
  @State private loading: boolean = false;
  @State private errorText: string = '';

  private readonly tabs: string[] = ['Все', 'Избранное', 'Недавние'];

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      const records: DirectLocationRecord[] = await DirectBackendRuntime.fetchLocations();
      this.locations = records.map((r: DirectLocationRecord): PickerLocation => ({
        id: r.id,
        countryCode: r.countryCode,
        country: r.country,
        city: r.city,
        region: r.region,
        host: r.host,
        latency: -1
      }));
      if (this.locations.length === 0) {
        this.errorText = DirectBackendRuntime.baseURLString.length === 0
          ? 'Каталог локаций будет доступен после подключения backend.'
          : 'Для этой подписки пока нет доступных серверов.';
      }
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : `${err}`;
      this.errorText = msg.length > 0 ? msg : 'Не удалось загрузить локации';
    } finally {
      this.loading = false;
    }
    if (this.locations.length > 0) void this.probe();
  }

  private async probe(): Promise<void> {
    for (let i = 0; i < this.locations.length; i++) {
      const host: string = this.locations[i].host ?? '';
      if (host.length === 0) continue;
      const client = http.createHttp();
      const started: number = Date.now();
      try {
        const url: string = host.startsWith('http') ? host : `https://${host}`;
        await client.request(url, { method: http.RequestMethod.HEAD, connectTimeout: 3000, readTimeout: 3000 });
        const ms: number = Date.now() - started;
        const item: PickerLocation = this.locations[i];
        this.locations = [...this.locations.slice(0, i), {
          id: item.id, countryCode: item.countryCode, country: item.country, city: item.city,
          region: item.region, host: item.host, latency: ms
        }, ...this.locations.slice(i + 1)];
      } catch {
        // Unknown latency remains —; this is intentionally not a fake value.
      } finally {
        client.destroy();
      }
    }
  }

  private filtered(): PickerLocation[] {
    let source: PickerLocation[] = this.locations;
    if (this.tab === 1) source = this.locations.filter((r: PickerLocation) => this.favorites.indexOf(r.id) >= 0);
    if (this.tab === 2) source = this.recent.map((id: string): PickerLocation | undefined => this.locations.find((r: PickerLocation) => r.id === id)).filter((r: PickerLocation | undefined): r is PickerLocation => r !== undefined);
    const q: string = this.query.trim().toLowerCase();
    if (q.length > 0) {
      source = source.filter((r: PickerLocation) => r.country.toLowerCase().includes(q) || r.city.toLowerCase().includes(q) || r.countryCode.toLowerCase().includes(q) || r.region.toLowerCase().includes(q));
    }
    return source.slice().sort((a: PickerLocation, b: PickerLocation) => {
      if (a.latency >= 0 && b.latency >= 0) return a.latency - b.latency;
      if (a.latency >= 0) return -1;
      if (b.latency >= 0) return 1;
      return `${a.country} ${a.city}`.localeCompare(`${b.country} ${b.city}`);
    });
  }

  private selectAuto(): void {
    this.selected = 'auto';
    VpnServerSelection.set({ id: 'auto', displayName: 'Авто', countryCode: '' });
    DirectHaptics.selection();
    this.onClose();
  }

  private selectServer(item: PickerLocation): void {
    this.selected = item.id;
    VpnServerSelection.set({ id: item.id, displayName: `${item.country} · ${item.city}`, countryCode: item.countryCode });
    const recent: string[] = [item.id, ...this.recent.filter((id: string) => id !== item.id)].slice(0, 10);
    this.recent = recent;
    writeIds(RECENT_KEY, recent);
    DirectHaptics.selection();
    this.onClose();
  }

  private toggleFavorite(item: PickerLocation): void {
    const next: string[] = this.favorites.indexOf(item.id) >= 0
      ? this.favorites.filter((id: string) => id !== item.id)
      : [item.id, ...this.favorites];
    this.favorites = next;
    writeIds(FAVORITES_KEY, next);
    DirectHaptics.selection();
  }

  build() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text('01').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
            Row().width(14).height(2).backgroundColor(DirectTheme.acid).margin({ left: 7, right: 7 });
            Text('SERVER / LOCATIONS').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          }
          Text('Локации').fontSize(34).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 5 });
          Text('Выберите сервер для текущего подключения').fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.muted).margin({ top: 5 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Text('×').fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).width(38).height(38).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink)
          .onClick(() => { DirectHaptics.navigation(); this.onClose(); });
      }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 15 });

      Row() {
        Text('⌕').fontSize(12).fontColor(DirectTheme.green).margin({ right: 9 });
        TextInput({ placeholder: 'Страна или город', text: this.query }).layoutWeight(1).height(44).fontSize(13).fontColor(DirectTheme.ink).backgroundColor(Color.Transparent)
          .onChange((v: string) => this.query = v);
        if (this.query.length > 0) Text('СБРОС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace').onClick(() => this.query = '');
      }.width('100%').height(44).padding({ left: 13, right: 13 }).margin({ left: 20, right: 20 }).backgroundColor('#73FFFFFF').border({ width: 1, color: DirectTheme.line });

      Row() {
        ForEach(this.tabs, (label: string, index: number) => {
          Row() {
            Text(label).fontSize(10).fontWeight(this.tab === index ? FontWeight.Bold : FontWeight.Medium).fontColor(DirectTheme.ink);
            if (index === 1) Text(String(this.favorites.length).padStart(2, '0')).fontSize(7).fontWeight(FontWeight.Bold).fontColor(this.tab === index ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace').margin({ left: 5 });
          }.layoutWeight(1).height(40).justifyContent(FlexAlign.Center)
            .border({ width: { bottom: this.tab === index ? 2 : 1 }, color: this.tab === index ? DirectTheme.ink : DirectTheme.line })
            .onClick(() => { this.tab = index; DirectHaptics.selection(); });
        });
      }.width('100%').padding({ left: 20, right: 20, top: 5 });

      if (this.loading) Text('Загрузка локаций…').fontSize(12).fontColor(DirectTheme.muted).margin({ top: 18, left: 20 });
      if (this.errorText.length > 0) Text(this.errorText).fontSize(11).fontColor(DirectTheme.muted).padding({ left: 20, right: 20, top: 12 });

      Scroll() {
        Column() {
          if (this.query.length === 0 && this.tab === 0) {
            Row() {
              Text('A').fontSize(16).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(38).height(38).textAlign(TextAlign.Center)
                .backgroundColor(this.selected === 'auto' ? DirectTheme.ink : DirectTheme.panel);
              Column() {
                Row() {
                  Text('SMART ROUTE').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
                  if (this.selected === 'auto') Text('АКТИВНО').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ left: 6 });
                }
                Text('Автовыбор').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).margin({ top: 3 });
                Text('Лучший маршрут по задержке и доступности').fontSize(9.5).fontColor(DirectTheme.muted).margin({ top: 3 }).maxLines(1);
              }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 11 });
              Column() {
                Text('СЕЙЧАС').fontSize(7).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
                Text(this.selected === 'auto' ? 'АВТО' : '—').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 3 });
              }.alignItems(HorizontalAlign.End).margin({ right: 8 });
              Text(this.selected === 'auto' ? '✓' : '›').fontSize(12).fontColor(this.selected === 'auto' ? DirectTheme.green : DirectTheme.muted);
            }.width('100%').constraintSize({ minHeight: 76 }).padding({ left: 20, right: 20 }).backgroundColor(this.selected === 'auto' ? DirectTheme.acidSelected : Color.Transparent)
              .border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => this.selectAuto());
          }

          Row() {
            Column() {
              Text('02 / VPN DIRECT').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace');
              Text(this.tab === 0 ? 'Доступные серверы' : this.tabs[this.tab]).fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).margin({ top: 2 });
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Column() {
              Text(String(this.filtered().length).padStart(2, '0')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
              Text('ЛОКАЦИЙ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
            }.alignItems(HorizontalAlign.End);
          }.width('100%').padding({ left: 20, right: 20, top: 11, bottom: 11 }).backgroundColor('#0B141714').border({ width: { bottom: 1 }, color: DirectTheme.line });

          if (this.filtered().length === 0) {
            Column() {
              Text(this.query.length > 0 ? 'Ничего не найдено' : 'Нет доступных серверов').fontSize(15).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink);
              Text(this.query.length > 0 ? 'Попробуйте другое название страны или города' : 'Для этой подписки пока нет локаций').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 8 });
            }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 60, bottom: 60 });
          } else {
            ForEach(this.filtered(), (item: PickerLocation, index: number) => this.serverRow(item, index + 1), (item: PickerLocation) => item.id);
          }
          Blank().height(24);
        }.width('100%').padding({ top: 10 });
      }.layoutWeight(1).scrollBar(BarState.Off);
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private serverRow(item: PickerLocation, index: number) {
    const isSelected: boolean = this.selected === item.id;
    const isFavorite: boolean = this.favorites.indexOf(item.id) >= 0;
    const ping: string = item.latency >= 0 ? `${item.latency} ms` : '—';
    const high: boolean = item.latency > 100;
    Row() {
      Text(String(index).padStart(2, '0')).fontSize(8).fontWeight(FontWeight.Bold).fontColor(isSelected ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace').width(21);
      Stack() {
        Text(item.countryCode.length === 2 ? item.countryCode.toUpperCase() : '—').fontSize(7).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(31).height(21).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink);
      }.width(31).height(21);
      Column() {
        Text(item.city.length > 0 ? item.city.toUpperCase() : item.country.toUpperCase()).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).maxLines(1);
        Text(item.country.toUpperCase()).fontSize(7).fontWeight(FontWeight.Bold).fontColor(isSelected ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace').margin({ top: 3 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 });
      Column() {
        Row() { Text('●').fontSize(6).fontColor(high ? DirectTheme.danger : DirectTheme.green); Text(ping).fontSize(8).fontWeight(FontWeight.Bold).fontColor(high ? DirectTheme.danger : DirectTheme.ink).fontFamily('monospace').margin({ left: 4 }); }
        Text('LOAD —').fontSize(7).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 3 });
      }.alignItems(HorizontalAlign.End).width(62);
      Text(isFavorite ? '★' : '☆').fontSize(13).fontColor(isFavorite ? DirectTheme.green : DirectTheme.muted).width(28).height(34).textAlign(TextAlign.Center)
        .onClick(() => this.toggleFavorite(item));
      Text(isSelected ? '✓' : '›').fontSize(11).fontWeight(FontWeight.Bold).fontColor(isSelected ? DirectTheme.green : DirectTheme.muted).width(18).textAlign(TextAlign.Center);
    }.width('100%').minHeight(61).padding({ left: 20, right: 20 }).backgroundColor(isSelected ? DirectTheme.acidSelected : Color.Transparent)
      .border({ width: { bottom: 1 }, color: DirectTheme.line })
      .onClick(() => this.selectServer(item));
  }
}
