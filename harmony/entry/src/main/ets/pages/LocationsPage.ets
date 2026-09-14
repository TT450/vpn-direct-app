import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics } from '../ui/Haptics';
import { DirectIcon, DirectIconName } from '../ui/DirectIcons';
import { VpnServerSelection } from '../vpn/VpnServerSelection';
import { DirectBackendRuntime, DirectLocationRecord } from '../backend/DirectBackendRuntime';
import { DirectFlow } from '../ui/DirectFlows';
import { DirectSessionStore, SESSION_HAS_PREMIUM, SESSION_LOCATIONS_JSON } from '../model/DirectSessionStore';
import { http } from '@kit.NetworkKit';

interface LocationItem {
  id: string;
  code: string;
  country: string;
  city: string;
  latency: string;
  quality: string;
}

/**
 * Showcase order matches DirectServersPage: access → search → current card → list.
 */
@Component
export struct LocationsPage {
  @State private search: string = '';
  @State private selected: string = VpnServerSelection.get().id;
  @State private locations: LocationItem[] = [];
  @State private loading: boolean = false;
  @State private errorText: string = '';
  @StorageProp(SESSION_HAS_PREMIUM) private hasPremium: boolean = false;
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};

  aboutToAppear(): void {
    void this.reload();
  }

  private sanitizeDisplay(value: string): string {
    return value
      .replace(/\{\{[^}]*\}\}/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private mapRecord(record: DirectLocationRecord): LocationItem {
    let country = this.sanitizeDisplay(record.country);
    let city = this.sanitizeDisplay(record.city);
    if (country.length === 0) {
      country = record.id;
    }
    if (city.length === 0 || city.toLowerCase() === country.toLowerCase()) {
      city = record.region.length > 0 ? record.region : '—';
    }
    const rawCode = this.sanitizeDisplay(record.countryCode).toUpperCase();
    const code = rawCode.length > 0 ? rawCode : '—';
    return {
      id: record.id,
      code: code,
      country: country,
      city: city,
      latency: '— MS',
      quality: 'СТАБИЛЬНО'
    };
  }

  /**
   * Fires a lightweight HEAD probe to each location that has a non-empty host.
   * Updates latency and quality labels in-place after each probe completes.
   * Safe-fails silently — latency stays "— MS" if unreachable.
   */
  private async probeLatencies(records: DirectLocationRecord[]): Promise<void> {
    for (let i = 0; i < records.length; i++) {
      const record = records[i];
      const host = record.host ?? '';
      if (host.length === 0) {
        continue;
      }
      const url = host.startsWith('http') ? host : `https://${host}`;
      const client = http.createHttp();
      const t0 = Date.now();
      try {
        await client.request(url, {
          method: http.RequestMethod.HEAD,
          connectTimeout: 4000,
          readTimeout: 4000
        });
        const ms = Date.now() - t0;
        // Mutate the loaded item to show measured latency
        const idx = this.locations.findIndex((item: LocationItem) => item.id === record.id);
        if (idx >= 0) {
          const quality = ms < 100 ? 'ОТЛИЧНО' : ms < 250 ? 'ХОРОШО' : 'СТАБИЛЬНО';
          const updated: LocationItem = {
            id: this.locations[idx].id,
            code: this.locations[idx].code,
            country: this.locations[idx].country,
            city: this.locations[idx].city,
            latency: `${ms} MS`,
            quality: quality
          };
          this.locations = [
            ...this.locations.slice(0, idx),
            updated,
            ...this.locations.slice(idx + 1)
          ];
        }
      } catch {
        // probe failed — leave '— MS'
      } finally {
        client.destroy();
      }
    }
  }

  private planStripDetail(): string {
    const count = this.locations.length;
    if (this.hasPremium) {
      return `${count} локаций • можно сменить`;
    }
    return `${count} локаций • витрина`;
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    let loadedRecords: DirectLocationRecord[] = [];
    try {
      let records: DirectLocationRecord[] = [];
      if (DirectBackendRuntime.baseURLString.length > 0) {
        records = await DirectBackendRuntime.fetchLocations();
        AppStorage.setOrCreate<string>(SESSION_LOCATIONS_JSON, JSON.stringify(records));
      }
      if (records.length === 0) {
        records = DirectSessionStore.getLocations();
      }
      const mapped = records.map((record: DirectLocationRecord) => this.mapRecord(record));
      this.locations = mapped;
      loadedRecords = records;
      if (mapped.length === 0 && records.length === 0 && DirectBackendRuntime.baseURLString.length === 0) {
        this.errorText = '';
      }
    } catch (err) {
      this.locations = [];
      const message = err instanceof Error ? err.message : `${err}`;
      this.errorText = message.length > 0 ? message : 'Не удалось загрузить локации';
    } finally {
      this.loading = false;
    }
    // Background latency probes — non-blocking, safe-fail
    if (loadedRecords.length > 0) {
      void this.probeLatencies(loadedRecords);
    }
  }

  private filtered(): LocationItem[] {
    const q = this.search.trim().toLowerCase();
    if (q.length === 0) {
      return this.locations;
    }
    return this.locations.filter((item: LocationItem) =>
      item.country.toLowerCase().includes(q) ||
      item.city.toLowerCase().includes(q) ||
      item.code.toLowerCase().includes(q)
    );
  }

  private showcaseList(): LocationItem[] {
    const list = this.filtered();
    if (list.length === 0) {
      return [];
    }
    const match = list.find((item: LocationItem) => item.id === this.selected);
    return [match !== undefined ? match : list[0]];
  }

  private listWithoutCurrent(): LocationItem[] {
    const showcase = this.showcaseList();
    if (showcase.length === 0) {
      return this.filtered();
    }
    const currentId = showcase[0].id;
    return this.filtered().filter((item: LocationItem) => item.id !== currentId);
  }

  private select(item: LocationItem): void {
    this.selected = item.id;
    VpnServerSelection.set({
      id: item.id,
      displayName: `${item.country} · ${item.city}`
    });
    DirectHaptics.selection();
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column() {
            Text('DIRECT / LOCATIONS')
              .fontSize(DirectTypography.caption)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.muted)
              .fontFamily('monospace');
            Text('Локации')
              .fontSize(DirectTypography.pageTitle)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .margin({ top: 7 });
            Text(this.loading ? 'Загрузка…' :
              (this.locations.length > 0
                ? this.planStripDetail()
                : 'Нет локаций'))
              .fontSize(13)
              .fontColor(DirectTheme.muted)
              .margin({ top: 4 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Column() {
            DirectIcon({
              name: DirectIconName.ArrowClockwise,
              iconSize: 14,
              color: DirectTheme.ink,
              weight: 1.5
            });
          }
            .width(36).height(36)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .border({ width: 1, color: DirectTheme.line })
            .onClick(() => {
              DirectHaptics.navigation();
              void this.reload();
            });
        }.width('100%').margin({ bottom: 16 });

        // 1) Access actions first
        Row() {
          this.accessCard('ТАРИФЫ', 'Готовые планы', 'START · PLUS · PRO', false, DirectFlow.Plans);
          this.accessCard('КОНСТРУКТОР', 'Собрать свой', 'ДНИ · УСТРОЙСТВА · ТРАФИК', true, DirectFlow.Constructor);
        }.width('100%');

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor(DirectTheme.muted)
            .width('100%')
            .padding(12)
            .border({ width: 1, color: DirectTheme.line })
            .margin({ top: 14 });
        }

        // 2) Search
        Row() {
          DirectIcon({
            name: DirectIconName.Magnifyingglass,
            iconSize: 13,
            color: DirectTheme.muted,
            weight: 1.5
          });
          Blank().width(10);
          Search({ placeholder: 'Страна или город', value: this.search })            .onChange((value: string) => this.search = value)
            .layoutWeight(1)
            .height(43);
        }
          .width('100%')
          .height(43)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: DirectTheme.line })
          .margin({ top: 14 });

        if (!this.loading && this.locations.length === 0 && this.errorText.length === 0) {
          this.emptyLocations();
        }

        // 3) Current showcase card + 4) other list
        ForEach(this.showcaseList(), (server: LocationItem) => {
          this.currentCard(server);

          Row() {
            Text('ДРУГИЕ ЛОКАЦИИ')
              .fontSize(DirectTypography.caption)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
            Blank();
            Text(String(this.listWithoutCurrent().length))
              .fontSize(DirectTypography.caption)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.muted)
              .fontFamily('monospace');
          }
            .width('100%')
            .height(38)
            .margin({ top: 22 })
            .border({ width: { top: 1 }, color: DirectTheme.ink });

          Column() {
            ForEach(this.listWithoutCurrent(), (item: LocationItem) => {
              this.serverRow(item);
            }, (item: LocationItem) => item.id);
          }
            .width('100%')
            .border({ width: 1, color: DirectTheme.line });

          Text(this.hasPremium
            ? 'Нажмите на локацию, чтобы сменить сервер.'
            : 'Список из каталога Direct. После покупки тарифа локации станут переключаемыми.')
            .fontSize(9)
            .fontColor(DirectTheme.muted)
            .width('100%')
            .margin({ top: 10, bottom: 24 });
        }, (server: LocationItem) => server.id);

        Blank().height(12);
      }
        .width('100%')
        .padding({
          left: DirectTheme.pageHorizontal,
          right: DirectTheme.pageHorizontal,
          top: DirectTheme.pageTop,
          bottom: 0
        });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  private accessCard(kicker: string, title: string, detail: string, primary: boolean, flow: DirectFlow) {
    Column() {
      Row() {
        Text(kicker)
          .fontSize(8)
          .fontWeight(FontWeight.Bold)
          .fontColor(primary ? DirectTheme.acid : DirectTheme.ink)
          .fontFamily('monospace');
        Blank();
        DirectIcon({
          name: DirectIconName.ArrowUpRight,
          iconSize: 8,
          color: primary ? DirectTheme.acid : DirectTheme.muted,
          weight: 1.4
        });
      }
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(primary ? DirectTheme.paper : DirectTheme.ink)
        .margin({ top: 5 })
        .maxLines(1);
      Text(detail)
        .fontSize(8)
        .fontWeight(FontWeight.Medium)
        .fontColor(primary ? '#94FFFFFF' : DirectTheme.muted)
        .fontFamily('monospace')
        .margin({ top: 5 })
        .maxLines(1);
    }
      .layoutWeight(1)
      .constraintSize({ minHeight: 70 })
      .padding({ left: 11, right: 11, top: 10, bottom: 10 })
      .margin({ right: primary ? 0 : 8 })
      .backgroundColor(primary ? DirectTheme.ink : DirectTheme.paper)
      .border({ width: primary ? 1.5 : 1, color: primary ? DirectTheme.ink : DirectTheme.line })
      .onClick(() => {
        DirectHaptics.navigation();
        this.onFlow(flow);
      });
  }

  @Builder
  private currentCard(server: LocationItem) {
    Column() {
      Row() {
        Text('ЛОКАЦИЯ')
          .fontSize(DirectTypography.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.muted)
          .fontFamily('monospace');
        Blank();
        Text('○ ВИТРИНА')
          .fontSize(DirectTypography.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.muted)
          .fontFamily('monospace');
      }.width('100%');

      Row() {
        Text(server.code)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.acid)
          .fontFamily('monospace')
          .width(36).height(24)
          .textAlign(TextAlign.Center)
          .backgroundColor(DirectTheme.ink);
        Column() {
          Text(server.country)
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink);
          Text(server.city)
            .fontSize(10)
            .fontColor(DirectTheme.muted)
            .fontFamily('monospace')
            .margin({ top: 3 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 });
        Column() {
          Text(server.latency.toLowerCase().replace(' MS', ' ms'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.ink)
            .fontFamily('monospace');
          Text(server.quality)
            .fontSize(DirectTypography.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.green)
            .fontFamily('monospace')
            .margin({ top: 3 });
        }.alignItems(HorizontalAlign.End);
      }.width('100%').padding({ top: 14, bottom: 14 });

      Row() {
        Text(this.hasPremium ? 'ОБНОВИТЬ КОНФИГ' : 'ПОДКЛЮЧИТЬ ТАРИФ')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.acid)
          .fontFamily('monospace');
        Blank();
        DirectIcon({
          name: DirectIconName.ArrowRight,
          iconSize: 12,
          color: DirectTheme.acid,
          weight: 1.5
        });
      }
        .width('100%')
        .height(46)
        .padding({ left: 13, right: 13 })
        .backgroundColor(DirectTheme.ink)
        .onClick(() => {
          DirectHaptics.navigation();
          if (this.hasPremium) {
            this.onFlow(DirectFlow.ServerPicker);
          } else {
            this.onFlow(DirectFlow.Plans);
          }
        });
    }
      .width('100%')
      .padding(14)
      .margin({ top: 14 })
      .backgroundColor(DirectTheme.paper)
      .border({ width: 1.5, color: DirectTheme.ink });
  }

  @Builder
  private emptyLocations() {
    Column() {
      Text('Нет локаций')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(DirectTheme.ink);
      Text('Каталог ещё не загружен. Обновите или откройте тарифы VPN Direct.')
        .fontSize(12)
        .fontColor(DirectTheme.muted)
        .margin({ top: 8 });
      Row() {
        Text('Открыть тарифы')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(DirectTheme.acid);
        Blank();
        DirectIcon({
          name: DirectIconName.ArrowRight,
          iconSize: 12,
          color: DirectTheme.acid,
          weight: 1.5
        });
      }
        .width('100%')
        .height(48)
        .padding({ left: 14, right: 14 })
        .backgroundColor(DirectTheme.ink)
        .margin({ top: 14 })
        .onClick(() => {
          DirectHaptics.navigation();
          this.onFlow(DirectFlow.Plans);
        });
    }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 14 });
  }

  @Builder
  private serverRow(item: LocationItem) {
    Row() {
      Text(item.code)
        .fontSize(8)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.acid)
        .fontFamily('monospace')
        .width(30).height(20)
        .textAlign(TextAlign.Center)
        .backgroundColor(DirectTheme.ink);
      Column() {
        Text(item.country)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.ink);
        Text(item.city)
          .fontSize(9)
          .fontColor(DirectTheme.muted)
          .fontFamily('monospace')
          .margin({ top: 3 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 11 });
      Column() {
        Text(item.latency.toLowerCase().replace(' MS', ' ms'))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.ink)
          .fontFamily('monospace');
        Text(item.quality)
          .fontSize(DirectTypography.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.green)
          .fontFamily('monospace')
          .margin({ top: 3 });
      }.alignItems(HorizontalAlign.End);
      DirectIcon({
        name: DirectIconName.ChevronRight,
        iconSize: 10,
        color: this.hasPremium ? DirectTheme.ink : DirectTheme.muted,
        weight: 1.6
      });
    }
      .width('100%')
      .height(58)
      .padding({ left: 12, right: 12 })
      .border({ width: { bottom: 1 }, color: DirectTheme.line })
      .backgroundColor(this.selected === item.id ? DirectTheme.acidSelected : Color.Transparent)
      .onClick(() => {
        if (this.hasPremium) {
          // Premium: select server directly
          this.select(item);
        } else {
          // Showcase: open Plans
          this.onFlow(DirectFlow.Plans);
        }
      });
  }
}
