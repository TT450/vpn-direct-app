import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';
import { ImportedSubscriptionStore } from '../vpn/ImportedSubscriptionStore';
import { DirectIcon, DirectIconName } from './DirectIcons';

@Component
export struct DirectAccessParityV2 {
  onClose: () => void = () => {};
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @State context: string = '';
  aboutToAppear(): void { this.context = AppStorage.get<string>('direct_access_choice_context') ?? ''; }
  private importedCount(): number { return ImportedSubscriptionStore.list().length; }
  private connectionMethodCount(): number { return this.importedCount() === 0 ? 1 : 3; }
  build() {
    Scroll() { Column() {
      Row() { Column() { Text('ПОДКЛЮЧЕНИЕ / НАЧАЛО').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text('Выберите доступ').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 7 }); Text('Сначала VPN Direct, затем другие провайдеры').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 5 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { DirectIcon({ name: DirectIconName.ArrowLeft, iconSize: 14, color: DirectTheme.muted, weight: 1.6 }); }.width(36).height(36).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).onClick(() => { DirectHaptics.navigation(); this.onClose(); }); }.width('100%').padding({ top: DirectTheme.pageTop, bottom: 4 });
      if (this.context.length > 0) Text(this.context).fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.ink).width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 }).backgroundColor(DirectTheme.acidSelected).border({ width: 1, color: DirectTheme.line }).margin({ top: 16 });
      Column() { Text('СЕЙЧАС НЕ ЗАЩИЩЕНО').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace'); Text('У вас пока нет активного подключения').fontSize(21).fontWeight(600).fontColor(DirectTheme.white).margin({ top: 7 }); Text('Оформите тариф VPN Direct или подключите внешнюю подписку.').fontSize(10).fontColor('#80FFFFFF').margin({ top: 7 }); }.width('100%').constraintSize({ minHeight: 112 }).padding(17).backgroundColor(DirectTheme.panel).margin({ top: 24 });
      this.sectionHeader('VPN DIRECT', String(this.connectionMethodCount()).padStart(2, '0')); this.choice('PLUS', 'Тарифы VPN Direct', 'Пресеты и конструктор · Plus рекомендуем', () => this.onFlow(DirectFlow.Plans));
      this.sectionHeader('ДРУГИЕ ПРОВАЙДЕРЫ', this.importedCount() > 0 ? '02' : '01');
      if (this.importedCount() > 0) { this.choice('SUB', 'Выбрать из добавленных', 'Внешние подписки в приложении', () => this.onFlow(DirectFlow.Subscription)); this.choice('URL', 'Добавить URL', 'Подписка любого провайдера', () => this.onFlow(DirectFlow.ImportText)); } else this.choice('URL', 'Добавить внешнюю подписку', 'QR, ссылка, файл или конфиг', () => this.onFlow(DirectFlow.ImportText));
      Blank().height(24);
    }.width('100%').padding({ left: 20, right: 20, bottom: 24 }); }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  @Builder private sectionHeader(title: string, meta: string) { Row() { Text(title).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text(meta).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(38).margin({ top: 22 }).border({ width: { top: 1 }, color: DirectTheme.ink }); }
  @Builder private choice(mark: string, title: string, subtitle: string, action: () => void) { Row() { Text(mark).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').textAlign(TextAlign.Center).width(45).height(42).backgroundColor(DirectTheme.ink); Column() { Text(title).fontSize(13).fontWeight(600).fontColor(DirectTheme.ink); Text(subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 }); DirectIcon({ name: DirectIconName.ArrowRight, iconSize: 11, color: DirectTheme.ink, weight: 1.5 }); }.width('100%').constraintSize({ minHeight: 70 }).border({ width: { bottom: 1 }, color: DirectTheme.line }).onClick(() => { DirectHaptics.selection(); action(); }); }
}
