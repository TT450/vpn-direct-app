import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics } from '../ui/Haptics';
import { DirectFlow } from '../ui/DirectFlows';
import { DirectIcon, DirectIconName } from '../ui/DirectIcons';
import { SESSION_HAS_SUBSCRIPTION, SESSION_PLAN_NAME, SESSION_REMAINING_DAYS } from '../model/DirectSessionStore';
import { ImportedSubscriptionStore, ImportedSubscription } from '../vpn/ImportedSubscriptionStore';

/** Pixel port of DirectManagementPage. VPN Direct has one subscription model; no Free/Premium UI. */
@Component
export struct ManagementPage {
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  onAddSubscription: () => void = () => {};
  @StorageProp(SESSION_HAS_SUBSCRIPTION) private hasSubscription: boolean = false;
  @StorageProp(SESSION_PLAN_NAME) private planName: string = '';
  @StorageProp(SESSION_REMAINING_DAYS) private remainingDays: number = 0;
  @State private importedSubs: ImportedSubscription[] = [];
  @State private activeImportId: string = '';
  @StorageProp('direct_import_ts') @Watch('onImportSignal') private importTs: number = 0;

  onImportSignal(): void { this.refreshImported(); }
  aboutToAppear(): void { this.refreshImported(); }
  private refreshImported(): void { this.importedSubs = ImportedSubscriptionStore.list(); this.activeImportId = ImportedSubscriptionStore.activeId(); }
  private activateSub(sub: ImportedSubscription): void { ImportedSubscriptionStore.setActive(sub.id); this.activeImportId = sub.id; DirectHaptics.selection(); }
  private hasPlan(): boolean { return this.hasSubscription && this.planName.trim().length > 0; }
  private shownPlan(): string { return this.planName.trim().length > 0 ? this.planName.toUpperCase() : 'VPN DIRECT'; }
  private planSummary(): string { return this.planName.trim().length > 0 ? `${this.planName} · VPN Direct` : 'VPN Direct'; }

  build() {
    Scroll() { Column() {
      Text('DIRECT / MANAGEMENT').fontSize(DirectTypography.caption).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace').width('100%');
      Text('Управление').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 7 });
      Text('Подписка, лимиты и настройки VPN Direct').fontSize(13).fontColor(DirectTheme.muted).width('100%').margin({ top: 4, bottom: 16 });

      if (this.hasPlan()) {
        Column() {
          Column() {
            Row() {
              Column() { Text('01 / ПОДПИСКА').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#BFA8F069').fontFamily('monospace'); Text(this.shownPlan()).fontSize(24).fontWeight(600).fontColor(DirectTheme.white).fontFamily('monospace').margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
              Text('● АКТИВНА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace');
            }.width('100%');
            Text(this.planSummary()).fontSize(9).fontColor('#94FFFFFF').fontFamily('monospace').margin({ top: 8 });
            Row().height(1).width('100%').backgroundColor('#29FFFFFF').margin({ top: 14, bottom: 14 });
            Row() {
              Column() { Text('ДО ОКОНЧАНИЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#8CFFFFFF').fontFamily('monospace'); Text(`${this.remainingDays} дней`).fontSize(20).fontWeight(600).fontColor(DirectTheme.white).fontFamily('monospace').margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
              Column() { Text('СТАТУС').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#8CFFFFFF').fontFamily('monospace'); Text('АКТИВНА').fontSize(11).fontWeight(FontWeight.Bold).fontColor(DirectTheme.white).fontFamily('monospace').margin({ top: 4 }); }.alignItems(HorizontalAlign.End);
            }.width('100%');
          }.width('100%').padding(15).backgroundColor(DirectTheme.ink);
          Text('Управление').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#000000').width('100%').height(48).textAlign(TextAlign.Center).backgroundColor(DirectTheme.acid)
            .onClick(() => { DirectHaptics.selection(); this.onFlow(DirectFlow.Plans); });
        }.width('100%').border({ width: 1.5, color: DirectTheme.ink });
      }

      Row() {
        Column() { Text('VPN DIRECT').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#B8A8F069').fontFamily('monospace'); Text(this.hasPlan() ? 'Продлить подписку' : 'Выбрать тариф').fontSize(16).fontWeight(600).fontColor(DirectTheme.acid).margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 12, color: DirectTheme.acid, weight: 1.8 });
      }.width('100%').height(62).padding({ left: 15, right: 15 }).backgroundColor(DirectTheme.ink).margin({ top: this.hasPlan() ? 12 : 0 }).onClick(() => { DirectHaptics.navigation(); this.onFlow(DirectFlow.Plans); });

      this.section('02 / ИСПОЛЬЗОВАНИЕ');
      Row() { Text('VPN TRAFFIC').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Blank(); Text('—').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); }.width('100%').padding({ top: 13, bottom: 8 });
      Row().width('100%').height(5).backgroundColor(DirectTheme.line);

      this.section('03 / НАСТРОЙКА');
      this.row('Изменить тариф', 'ГОТОВЫЕ ПЛАНЫ', DirectFlow.Plans);
      this.row('Изменить устройства', 'КОНСТРУКТОР', DirectFlow.Constructor);
      this.row('Изменить трафик', 'КОНСТРУКТОР', DirectFlow.Constructor);

      this.section('04 / ДРУГИЕ ПОДПИСКИ');
      if (this.importedSubs.length === 0) {
        Text('Нет добавленных подписок').fontSize(12).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%').margin({ top: 13 });
        Text('Добавьте стороннюю подписку, если хотите использовать её вместе с VPN Direct.').fontSize(9).fontColor(DirectTheme.muted).width('100%').margin({ top: 5, bottom: 13 });
      } else {
        ForEach(this.importedSubs, (sub: ImportedSubscription) => {
          Row() {
            Column() {
              Row() { Text(this.activeImportId === sub.id ? '● АКТИВНА' : '○').fontSize(9).fontWeight(FontWeight.Bold).fontColor(this.activeImportId === sub.id ? DirectTheme.green : DirectTheme.muted).fontFamily('monospace').margin({ right: 7 }); Text(sub.url.length > 0 ? 'URL' : 'JSON').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); }
              Text(sub.name).fontSize(13).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 3 }).maxLines(1);
              if (sub.url.length > 0) Text(sub.url.length > 48 ? `${sub.url.substring(0, 48)}…` : sub.url).fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 2 }).maxLines(1);
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Text(this.activeImportId === sub.id ? 'АКТИВНА' : 'Использовать').fontSize(9).fontWeight(FontWeight.Bold).fontColor(this.activeImportId === sub.id ? DirectTheme.green : DirectTheme.acid).fontFamily('monospace').padding({ left: 10, right: 10 }).height(34).textAlign(TextAlign.Center).backgroundColor(this.activeImportId === sub.id ? DirectTheme.fieldFill : DirectTheme.ink)
              .onClick(() => { if (this.activeImportId !== sub.id) this.activateSub(sub); });
          }.width('100%').constraintSize({ minHeight: 64 }).padding({ top: 10, bottom: 10 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
        }, (sub: ImportedSubscription) => sub.id);
      }
      Row() { Text('+').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid); Text('ДОБАВИТЬ ПОДПИСКУ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').margin({ left: 9 }); Blank(); DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 9, color: DirectTheme.acid, weight: 1.5 }); }
        .width('100%').height(46).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 4 }).onClick(() => { DirectHaptics.navigation(); this.onAddSubscription(); });
      Blank().height(28);
    }.padding({ left: 20, right: 20, top: DirectTheme.pageTop, bottom: 20 }); }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder section(title: string) { Row() { Text(title).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); }.width('100%').height(38).margin({ top: 24 }).border({ width: { top: 1 }, color: DirectTheme.ink }); }
  @Builder row(title: string, detail: string, flow: DirectFlow) { Row() { Column() { Text(title).fontSize(12).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink); Text(detail).fontSize(9).fontColor(DirectTheme.muted).fontFamily('monospace').margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); DirectIcon({ name: DirectIconName.ArrowUpRight, iconSize: 10, color: DirectTheme.ink, weight: 1.8 }); }.width('100%').constraintSize({ minHeight: 52 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); this.onFlow(flow); }); }
}