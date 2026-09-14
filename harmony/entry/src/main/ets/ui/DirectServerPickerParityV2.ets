import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectBackendRuntime, DirectLocationRecord } from '../backend/DirectBackendRuntime';
import { VpnServerSelection } from '../vpn/VpnServerSelection';
import { DirectFlag } from './DirectFlag';
import { DirectIcon, DirectIconName } from './DirectIcons';

const FAVORITES_KEY: string = 'direct_server_favorites';
const RECENT_KEY: string = 'direct_server_recent';
function readIds(key: string): string[] { const raw = AppStorage.get<string>(key) ?? '[]'; try { const value = JSON.parse(raw) as Object; return Array.isArray(value) ? value as string[] : []; } catch { return []; } }
function writeIds(key: string, ids: string[]): void { AppStorage.setOrCreate<string>(key, JSON.stringify(ids.slice(0, 20))); }
function pingValue(item: DirectLocationRecord): number { return item.latencyMs !== undefined && item.latencyMs > 0 ? item.latencyMs : -1; }

@Component
export struct DirectServerPickerParityV2 {
  onClose: () => void = () => {};
  @State selected: string = VpnServerSelection.get().id;
  @State query: string = '';
  @State tab: number = 0;
  @State locations: DirectLocationRecord[] = [];
  @State favorites: string[] = readIds(FAVORITES_KEY);
  @State recent: string[] = readIds(RECENT_KEY);
  @State loading: boolean = false;
  @State errorText: string = '';
  private readonly tabs: string[] = ['Все', 'Избранное', 'Недавние'];
  aboutToAppear(): void { void this.load(); }
  private async load(): Promise<void> { this.loading = true; this.errorText = ''; try { this.locations = await DirectBackendRuntime.fetchLocations(); if (this.locations.length === 0) this.errorText = DirectBackendRuntime.baseURLString.length === 0 ? 'Каталог локаций будет доступен после подключения backend.' : 'Для этой подписки пока нет доступных серверов.'; } catch (err) { const message = err instanceof Error ? err.message : `${err}`; this.errorText = message.length > 0 ? message : 'Не удалось загрузить локации'; } finally { this.loading = false; } }
  private filtered(): DirectLocationRecord[] {
    let source: DirectLocationRecord[] = this.locations;
    if (this.tab === 1) source = source.filter((r: DirectLocationRecord) => this.favorites.indexOf(r.id) >= 0);
    if (this.tab === 2) source = this.recent.map((id: string): DirectLocationRecord | undefined => this.locations.find((r: DirectLocationRecord) => r.id === id)).filter((r: DirectLocationRecord | undefined): r is DirectLocationRecord => r !== undefined);
    const q = this.query.trim().toLowerCase();
    if (q.length > 0) source = source.filter((r: DirectLocationRecord) => r.country.toLowerCase().includes(q) || r.city.toLowerCase().includes(q) || r.countryCode.toLowerCase().includes(q) || r.region.toLowerCase().includes(q));
    return source.slice().sort((a: DirectLocationRecord, b: DirectLocationRecord) => {
      const ap = pingValue(a); const bp = pingValue(b);
      if (ap > 0 && bp > 0) return ap - bp;
      if (ap > 0) return -1;
      if (bp > 0) return 1;
      return `${a.country} ${a.city}`.localeCompare(`${b.country} ${b.city}`);
    });
  }
  private selectAuto(): void { this.selected = 'auto'; VpnServerSelection.set({ id: 'auto', displayName: 'Авто', countryCode: '' }); DirectHaptics.selection(); this.onClose(); }
  private selectServer(item: DirectLocationRecord): void { this.selected = item.id; VpnServerSelection.set({ id: item.id, displayName: `${item.country} · ${item.city}`, countryCode: item.countryCode }); const next = [item.id, ...this.recent.filter((id: string) => id !== item.id)].slice(0, 10); this.recent = next; writeIds(RECENT_KEY, next); DirectHaptics.selection(); this.onClose(); }
  private toggleFavorite(item: DirectLocationRecord): void { const next = this.favorites.indexOf(item.id) >= 0 ? this.favorites.filter((id: string) => id !== item.id) : [item.id, ...this.favorites]; this.favorites = next; writeIds(FAVORITES_KEY, next); DirectHaptics.selection(); }
  private latencyLabel(item: DirectLocationRecord): string { const p = pingValue(item); return p > 0 ? `${p} MS` : '— MS'; }
  private loadLabel(item: DirectLocationRecord): string { return item.loadPercent !== undefined && item.loadPercent >= 0 ? `LOAD ${Math.round(item.loadPercent)}%` : 'LOAD —'; }
  private pingDanger(item: DirectLocationRecord): boolean { return pingValue(item) > 100; }

  build() {
    Column() {
      Row() { Column() { Row() { Text('01').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); Row().width(14).height(2).backgroundColor(DirectTheme.acid).margin({ left: 7, right: 7 }); Text('SERVER / LOCATIONS').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); } Text('Локации').fontSize(34).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 5 }); Text('Выберите сервер для текущего подключения').fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.muted).margin({ top: 5 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { DirectIcon({ name: DirectIconName.Xmark, iconSize: 12, color: DirectTheme.acid, weight: 1.8 }); }.width(38).height(38).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 15 });
      Row() { DirectIcon({ name: DirectIconName.Magnifyingglass, iconSize: 12, color: DirectTheme.green, weight: 1.6 }); TextInput({ placeholder: 'Страна или город', text: this.query }).layoutWeight(1).height(44).fontSize(13).fontColor(DirectTheme.ink).backgroundColor(Color.Transparent).onChange((v: string) => this.query = v); if (this.query.length > 0) Text('СБРОС').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace').onClick(() => this.query = ''); }.width('100%').height(44).padding({ left: 13, right: 13 }).margin({ left: 20, right: 20 }).backgroundColor('#73FFFFFF').border({ width: 1, color: DirectTheme.line });
      Row() { ForEach(this.tabs, (label: string, index: number) => { Row() { Text(label).fontSize(10).fontWeight(this.tab === index ? FontWeight.Bold : FontWeight.Medium).fontColor(DirectTheme.ink); if (index === 1) Text(String(this.favorites.length).padStart(2, '0')).fontSize(7).fontWeight(FontWeight.Bold).fontColor(this.tab === index ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace').margin({ left: 5 }); }.layoutWeight(1).height(40).justifyContent(FlexAlign.Center).border({ width: { bottom: this.tab === index ? 2 : 1 }, color: this.tab === index ? DirectTheme.ink : DirectTheme.line }).onClick(() => { this.tab = index; DirectHaptics.selection(); }); }); }.width('100%').padding({ left: 20, right: 20, top: 5 });
      if (this.loading) Text('Загрузка локаций…').fontSize(12).fontColor(DirectTheme.muted).margin({ top: 18, left: 20 });
      if (this.errorText.length > 0) Text(this.errorText).fontSize(11).fontColor(DirectTheme.muted).padding({ left: 20, right: 20, top: 12 });
      Scroll() { Column() {
        if (this.query.length === 0 && this.tab === 0) Row() { DirectFlag({ code: 'auto', width: 38, height: 38 }); Column() { Row() { Text('SMART ROUTE').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); if (this.selected === 'auto') Text('АКТИВНО').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ left: 6 }); } Text('Автовыбор').fontSize(15).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).margin({ top: 3 }); Text('Лучший маршрут по задержке и доступности').fontSize(9.5).fontWeight(FontWeight.Medium).fontColor(DirectTheme.muted).margin({ top: 3 }).maxLines(1); }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 11 }); Column() { Text('СЕЙЧАС').fontSize(7).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(this.selected === 'auto' ? 'АВТО' : '—').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 3 }); }.alignItems(HorizontalAlign.End).margin({ right: 8 }); DirectIcon({ name: this.selected === 'auto' ? DirectIconName.Checkmark : DirectIconName.ChevronRight, iconSize: 12, color: this.selected === 'auto' ? DirectTheme.green : DirectTheme.muted, weight: 1.8 }); }.width('100%').constraintSize({ minHeight: 76 }).padding({ left: 20, right: 20 }).backgroundColor(this.selected === 'auto' ? DirectTheme.acidSelected : Color.Transparent).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => this.selectAuto());
        Row() { Column() { Text('02 / VPN DIRECT').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); Text(this.tab === 0 ? 'Доступные серверы' : this.tabs[this.tab]).fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).margin({ top: 2 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { Text(String(this.filtered().length).padStart(2, '0')).fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Text('ЛОКАЦИЙ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); }.alignItems(HorizontalAlign.End); }.width('100%').padding({ left: 20, right: 20, top: 11, bottom: 11 }).backgroundColor('#0B141714').border({ width: { bottom: 1 }, color: DirectTheme.line });
        if (this.filtered().length === 0) Column() { Text(this.query.length > 0 ? 'Ничего не найдено' : 'Нет доступных серверов').fontSize(15).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Text(this.query.length > 0 ? 'Попробуйте другое название страны или города' : 'Для этой подписки пока нет локаций').fontSize(10).fontColor(DirectTheme.muted).margin({ top: 8 }); }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 60, bottom: 60 });
        else ForEach(this.filtered(), (item: DirectLocationRecord, index: number) => this.serverRow(item, index + 1), (item: DirectLocationRecord) => item.id);
        Blank().height(24);
      }.width('100%').padding({ top: 10 }); }.layoutWeight(1).scrollBar(BarState.Off);
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private serverRow(item: DirectLocationRecord, index: number) { const selected = this.selected === item.id; const favorite = this.favorites.indexOf(item.id) >= 0; Row() { Text(String(index).padStart(2, '0')).fontSize(8).fontWeight(FontWeight.Bold).fontColor(selected ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace').width(21); DirectFlag({ code: item.countryCode, width: 31, height: 21 }); Column() { Text(item.city.length > 0 ? item.city.toUpperCase() : item.country.toUpperCase()).fontSize(13).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).maxLines(1); Text(item.country.toUpperCase()).fontSize(7).fontWeight(FontWeight.Bold).fontColor(selected ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace').margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 }); Column() { Row({ space: 4 }) { Circle().width(5).height(5).fill(this.pingDanger(item) ? DirectTheme.danger : DirectTheme.green); Text(this.latencyLabel(item)).fontSize(8).fontWeight(FontWeight.Bold).fontColor(this.pingDanger(item) ? DirectTheme.danger : DirectTheme.ink).fontFamily('monospace'); } Text(this.loadLabel(item)).fontSize(7).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 3 }); }.alignItems(HorizontalAlign.End).width(62); Column() { DirectIcon({ name: DirectIconName.Star, iconSize: 11, color: favorite ? DirectTheme.green : DirectTheme.muted, weight: 1.6 }); }.width(34).height(34).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).onClick(() => this.toggleFavorite(item)); Column() { DirectIcon({ name: selected ? DirectIconName.Checkmark : DirectIconName.ChevronRight, iconSize: selected ? 10 : 9, color: selected ? DirectTheme.green : DirectTheme.muted, weight: 1.8 }); }.width(24).height(34).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center); }.width('100%').constraintSize({ minHeight: 61 }).padding({ left: 20, right: 20 }).backgroundColor(selected ? DirectTheme.acidSelected : Color.Transparent).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => this.selectServer(item)); }
}
