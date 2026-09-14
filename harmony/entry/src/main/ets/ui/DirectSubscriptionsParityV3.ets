import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { ImportedSubscriptionStore, ImportedSubscription } from '../vpn/ImportedSubscriptionStore';
import { SESSION_HAS_SUBSCRIPTION, SESSION_PLAN_NAME, SESSION_REMAINING_DAYS } from '../model/DirectSessionStore';
import { DirectIcon, DirectIconName } from './DirectIcons';

@Component
export struct DirectSubscriptionsParityV3 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State items: ImportedSubscription[] = [];
  @State activeId: string = '';
  @StorageProp(SESSION_HAS_SUBSCRIPTION) private hasDirect: boolean = false;
  @StorageProp(SESSION_PLAN_NAME) private planName: string = '';
  @StorageProp(SESSION_REMAINING_DAYS) private remainingDays: number = 0;
  aboutToAppear(): void { this.reload(); }
  private reload(): void { this.items = ImportedSubscriptionStore.list(); this.activeId = ImportedSubscriptionStore.activeId(); }
  private choose(item: ImportedSubscription): void { ImportedSubscriptionStore.setActive(item.id); this.reload(); DirectHaptics.selection(); this.onClose(); }
  private activateNative(): void { DirectHaptics.selection(); this.onFlow(DirectFlow.Plans); }
  private directDetail(): string { if (this.remainingDays > 0 && this.planName.length > 0) return `${this.remainingDays} дн · ${this.planName}`; if (this.remainingDays > 0) return `${this.remainingDays} дн · основной доступ аккаунта`; return 'Тариф VPN Direct на аккаунте'; }

  build() {
    Column() {
      Row() { Column() { Row() { Text('01').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); Row().width(14).height(2).backgroundColor(DirectTheme.acid).margin({ left: 7, right: 7 }); Text('ПОДКЛЮЧЕНИЕ / ПОДПИСКИ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); } Text('Подписки').fontSize(34).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 5 }); Text('VPN Direct — первым, добавленные — ниже').fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.muted).margin({ top: 5 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { DirectIcon({ name: DirectIconName.Xmark, iconSize: 12, color: DirectTheme.acid, weight: 1.8 }); }.width(38).height(38).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 15 }).border({ width: { bottom: 1 }, color: DirectTheme.line });

      if (!this.hasDirect && this.items.length === 0) this.emptyState();
      else Scroll() { Column() {
        if (this.hasDirect) this.nativeDirectBlock();
        if (this.items.length > 0) {
          Row() { Text('ДОБАВЛЕННЫЕ ПОДПИСКИ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text(this.items.length < 10 ? `0${this.items.length}` : String(this.items.length)).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(36).margin({ top: this.hasDirect ? 22 : 18 }).border({ width: { top: 1 }, color: DirectTheme.ink });
          ForEach(this.items, (item: ImportedSubscription) => this.row(item), (item: ImportedSubscription) => item.id);
        }
      }.width('100%').padding({ left: 20, right: 20, bottom: 28 }); }.layoutWeight(1).scrollBar(BarState.Off);
    }
  }

  @Builder private emptyState() {
    Column() { Text('Нет доступных подписок').fontSize(16).fontWeight(600).fontColor(DirectTheme.ink); Text('Оформите тариф VPN Direct или добавьте внешнюю подписку во вкладке Управление.').fontSize(12).fontColor(DirectTheme.muted).margin({ top: 14 }).maxLines(3); Row() { Text('ОТКРЫТЬ УПРАВЛЕНИЕ').fontSize(11).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Blank(); DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 12, color: DirectTheme.acid, weight: 1.5 }); }.width('100%').height(48).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink).margin({ top: 18 }).onClick(() => { DirectHaptics.navigation(); this.onClose(); this.onFlow(DirectFlow.Management); }); }.width('100%').height('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 24 });
  }

  @Builder private nativeDirectBlock() {
    Row() {
      Column() {
        Column() { Text('VPN DIRECT · ОСНОВНАЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); Text('VPN Direct').fontSize(20).fontWeight(600).fontColor(DirectTheme.white).margin({ top: 4 }); Text(this.directDetail()).fontSize(10).fontColor('#85FFFFFF').margin({ top: 4 }).maxLines(2); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Column() { Text('ОСНОВНАЯ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').padding({ left: 8, right: 8 }).height(27).textAlign(TextAlign.Center).border({ width: 1, color: '#B8A8F069' }); if (this.activeId === 'session_subscription') Row({ space: 5 }) { Text('АКТИВНА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); DirectIcon({ name: DirectIconName.Checkmark, iconSize: 11, color: DirectTheme.acid, weight: 1.8 }); }.margin({ top: 8 }); else DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 11, color: DirectTheme.acid, weight: 1.6 }).margin({ top: 8 }); }.alignItems(HorizontalAlign.End);
      }.width('100%').padding(16).backgroundColor(DirectTheme.ink).border({ width: 1, color: '#B8A8F069' });
    }.width('100%').margin({ top: 18 }).onClick(() => this.activateNative());
  }

  @Builder private row(item: ImportedSubscription) {
    const active = this.activeId === item.id;
    Row({ space: 12 }) {
      Text('URL').fontSize(10).fontWeight(FontWeight.Bold).fontColor(active ? DirectTheme.acid : DirectTheme.ink).fontFamily('monospace').textAlign(TextAlign.Center).width(48).height(42).backgroundColor(active ? DirectTheme.ink : '#B8FFFFFF');
      Column() { Row({ space: 7 }) { Text(item.name.length > 0 ? item.name : 'Подписка').fontSize(13).fontWeight(600).fontColor(DirectTheme.ink).maxLines(1); if (active) Text('АКТИВНА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%'); Text(item.url.length > 0 ? item.url : 'sing-box JSON').fontSize(10).fontColor(DirectTheme.muted).maxLines(1).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      DirectIcon({ name: active ? DirectIconName.Checkmark : DirectIconName.ArrowRight, iconSize: 11, color: active ? DirectTheme.green : DirectTheme.muted, weight: 1.6 });
    }.width('100%').constraintSize({ minHeight: 68 }).padding({ left: 12, right: 12 }).backgroundColor(active ? '#29A8F069' : '#B8FFFFFF').border({ width: 1, color: active ? DirectTheme.green : DirectTheme.line }).onClick(() => this.choose(item));
  }
}
