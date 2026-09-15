import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics } from '../ui/Haptics';
import { DirectFlow } from '../ui/DirectFlows';
import { DirectIcon, DirectIconName } from '../ui/DirectIcons';
import { SESSION_HAS_SUBSCRIPTION, SESSION_PLAN_NAME, SESSION_REMAINING_DAYS, SESSION_TRAFFIC_USED_GB, SESSION_TRAFFIC_LIMIT_GB } from '../model/DirectSessionStore';
import { ImportedSubscriptionStore, ImportedSubscription } from '../vpn/ImportedSubscriptionStore';

@Component
export struct ManagementPage {
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  onAddSubscription: () => void = () => {};
  @StorageProp(SESSION_HAS_SUBSCRIPTION) private hasSubscription: boolean = false;
  @StorageProp(SESSION_PLAN_NAME) private planName: string = '';
  @StorageProp(SESSION_REMAINING_DAYS) private remainingDays: number = 0;
  @StorageProp(SESSION_TRAFFIC_USED_GB) private trafficUsed: number = 0;
  @StorageProp(SESSION_TRAFFIC_LIMIT_GB) private trafficLimit: number = 0;
  @State private importedSubs: ImportedSubscription[] = [];
  @State private activeImportId: string = '';
  @StorageProp('direct_import_ts') @Watch('onImportSignal') private importTs: number = 0;

  onImportSignal(): void {
    this.refreshImported();
  }

  aboutToAppear(): void {
    this.refreshImported();
  }

  private refreshImported(): void {
    this.importedSubs = ImportedSubscriptionStore.list();
    this.activeImportId = ImportedSubscriptionStore.activeId();
  }

  private activateSub(sub: ImportedSubscription): void {
    ImportedSubscriptionStore.setActive(sub.id);
    this.activeImportId = sub.id;
    DirectHaptics.selection();
  }

  private hasPlan(): boolean {
    return this.hasSubscription;
  }

  private shownPlan(): string {
    return this.planName.trim().length > 0 ? this.planName.toUpperCase() : 'DIRECT';
  }

  private planSummary(): string {
    if (this.trafficLimit > 0) return `${this.trafficLimit} GB · VPN Direct`;
    return 'VPN Direct';
  }

  private expirationText(): string {
    if (!this.hasPlan() || this.remainingDays <= 0) return '—';
    const date = new Date(Date.now() + this.remainingDays * 86400000);
    const months: string[] = ['ЯНВ', 'ФЕВ', 'МАР', 'АПР', 'МАЙ', 'ИЮН', 'ИЮЛ', 'АВГ', 'СЕН', 'ОКТ', 'НОЯ', 'ДЕК'];
    return `${date.getDate()} ${months[date.getMonth()]}`;
  }

  private usageWidth(): number {
    if (this.trafficLimit <= 0) return 0;
    return Math.min(100, Math.max(0, this.trafficUsed / this.trafficLimit * 100));
  }

  build() {
    Scroll() {
      Column() {
        Text('DIRECT / MANAGEMENT')
          .fontSize(DirectTypography.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.muted)
          .fontFamily('monospace')
          .width('100%');
        Text('Управление')
          .fontSize(DirectTypography.pageTitle)
          .fontWeight(600)
          .fontColor(DirectTheme.ink)
          .margin({ top: 7 });
        Text('Подписка, лимиты и настройки VPN Direct')
          .fontSize(13)
          .fontColor(DirectTheme.muted)
          .width('100%')
          .margin({ top: 4, bottom: 16 });

        if (this.hasPlan()) {
          Column() {
            Column() {
              Row() {
                Column() {
                  Text('01 / ПОДПИСКА')
                    .fontSize(9)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#BFA8F069')
                    .fontFamily('monospace');
                  Text(this.shownPlan())
                    .fontSize(24)
                    .fontWeight(600)
                    .fontColor(DirectTheme.white)
                    .fontFamily('monospace')
                    .margin({ top: 4 });
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);
                Text('● АКТИВНА')
                  .fontSize(9)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(DirectTheme.acid)
                  .fontFamily('monospace')
                  .margin({ top: 3 });
              }
              .width('100%');

              Text(this.planSummary())
                .fontSize(9)
                .fontColor('#94FFFFFF')
                .fontFamily('monospace')
                .margin({ top: 8 })
                .maxLines(2);

              Row()
                .height(1)
                .width('100%')
                .backgroundColor('#29FFFFFF')
                .margin({ top: 14, bottom: 14 });

              Row() {
                Column() {
                  Text('ДО ОКОНЧАНИЯ')
                    .fontSize(9)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#8CFFFFFF')
                    .fontFamily('monospace');
                  Text(`${this.remainingDays} дней`)
                    .fontSize(20)
                    .fontWeight(600)
                    .fontColor(DirectTheme.white)
                    .fontFamily('monospace')
                    .margin({ top: 4 });
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);

                Column() {
                  Text('ОКОНЧАНИЕ')
                    .fontSize(9)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#8CFFFFFF')
                    .fontFamily('monospace');
                  Text(this.expirationText())
                    .fontSize(11)
                    .fontWeight(600)
                    .fontColor(DirectTheme.white)
                    .fontFamily('monospace')
                    .margin({ top: 4 });
                }
                .alignItems(HorizontalAlign.End);
              }
              .width('100%');
            }
            .width('100%')
            .padding(15)
            .backgroundColor(DirectTheme.ink);

            Text('Управление')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.Black)
              .width('100%')
              .height(48)
              .textAlign(TextAlign.Center)
              .backgroundColor(DirectTheme.acid)
              .onClick(() => {
                DirectHaptics.selection();
                this.onFlow(DirectFlow.Plans);
              });
          }
          .width('100%')
          .border({ width: 1.5, color: DirectTheme.ink });
        }

        Row() {
          Column() {
            Text(this.hasPlan() ? 'ПОДПИСКА' : 'VPN DIRECT')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor('#B8A8F069')
              .fontFamily('monospace');
            Text(this.hasPlan() ? 'Продлить подписку' : 'Выбрать тариф')
              .fontSize(16)
              .fontWeight(600)
              .fontColor(DirectTheme.acid)
              .margin({ top: 3 });
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1);
          DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 12, color: DirectTheme.acid, weight: 1.8 });
        }
        .width('100%')
        .height(62)
        .padding({ left: 15, right: 15 })
        .backgroundColor(DirectTheme.ink)
        .margin({ top: this.hasPlan() ? 12 : 0 })
        .onClick(() => {
          DirectHaptics.navigation();
          this.onFlow(DirectFlow.Plans);
        });

        this.section('02 / ИСПОЛЬЗОВАНИЕ');
        if (this.trafficLimit > 0) {
          Row() {
            Text('VPN TRAFFIC')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.muted)
              .fontFamily('monospace');
            Blank();
            Text(`${this.trafficUsed} / ${this.trafficLimit} GB`)
              .fontSize(10)
              .fontWeight(600)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
          }
          .width('100%')
          .padding({ top: 12, bottom: 8 });

          Stack() {
            Row()
              .width('100%')
              .height(5)
              .backgroundColor(DirectTheme.line);
            Row()
              .width(`${this.usageWidth()}%`)
              .height(5)
              .backgroundColor(DirectTheme.ink);
          }
          .width('100%')
          .height(5);
        } else {
          Row() {
            Text('VPN TRAFFIC')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.muted)
              .fontFamily('monospace');
            Blank();
            Text('—')
              .fontSize(10)
              .fontWeight(600)
              .fontColor(DirectTheme.ink)
              .fontFamily('monospace');
          }
          .width('100%')
          .padding({ top: 13, bottom: 13 });
        }

        this.section('03 / НАСТРОЙКА');
        this.row('Изменить тариф', 'ГОТОВЫЕ ПЛАНЫ', DirectFlow.Plans);
        this.row('Изменить устройства', 'КОНСТРУКТОР', DirectFlow.Constructor);
        this.row('Изменить трафик', 'КОНСТРУКТОР', DirectFlow.Constructor);

        this.section('04 / ДРУГИЕ ПОДПИСКИ');
        if (this.importedSubs.length === 0) {
          Column() {
            Text('Нет добавленных подписок')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(DirectTheme.ink);
            Text('Добавьте стороннюю подписку, если хотите использовать её вместе с VPN Direct.')
              .fontSize(9)
              .fontColor(DirectTheme.muted)
              .margin({ top: 5 });
          }
          .width('100%')
          .padding({ top: 13, bottom: 13 });
        } else {
          ForEach(this.importedSubs, (sub: ImportedSubscription) => {
            Row() {
              Column() {
                Text(sub.name)
                  .fontSize(12)
                  .fontWeight(600)
                  .fontColor(DirectTheme.ink)
                  .maxLines(1);
                Text(this.activeImportId === sub.id ? 'Добавлена · активна' : 'Добавлена извне')
                  .fontSize(9)
                  .fontColor(DirectTheme.muted)
                  .fontFamily('monospace')
                  .margin({ top: 3 });
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 9, color: DirectTheme.ink, weight: 1.8 });
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              if (this.activeImportId !== sub.id) this.activateSub(sub);
            });
            Row()
              .width('100%')
              .height(1)
              .backgroundColor(DirectTheme.line);
          }, (sub: ImportedSubscription) => sub.id);
        }

        Row() {
          DirectIcon({ name: DirectIconName.Plus, iconSize: 9, color: DirectTheme.acid, weight: 1.5 });
          Text('ДОБАВИТЬ ПОДПИСКУ')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace')
            .margin({ left: 9 });
          Blank();
          DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 9, color: DirectTheme.acid, weight: 1.5 });
        }
        .width('100%')
        .height(46)
        .padding({ left: 14, right: 14 })
        .backgroundColor(DirectTheme.ink)
        .margin({ top: 4 })
        .onClick(() => {
          DirectHaptics.navigation();
          this.onAddSubscription();
        });

        Blank().height(28);
      }
      .padding({ left: 20, right: 20, top: DirectTheme.pageTop, bottom: 20 });
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor(DirectTheme.paper);
  }

  @Builder
  section(title: string) {
    Row() {
      Text(title)
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.ink)
        .fontFamily('monospace');
      Blank();
    }
    .width('100%')
    .height(38)
    .margin({ top: 24 })
    .border({ width: { top: 1 }, color: DirectTheme.ink });
  }

  @Builder
  row(title: string, detail: string, flow: DirectFlow) {
    Row() {
      Column() {
        Text(title)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(DirectTheme.ink);
        Text(detail)
          .fontSize(9)
          .fontColor(DirectTheme.muted)
          .fontFamily('monospace')
          .margin({ top: 3 });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);
      DirectIcon({ name: DirectIconName.ArrowUpRight, iconSize: 9, color: DirectTheme.ink, weight: 1.8 });
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .border({ width: { bottom: 1 }, color: DirectTheme.line })
    .onClick(() => {
      DirectHaptics.selection();
      this.onFlow(flow);
    });
  }
}
