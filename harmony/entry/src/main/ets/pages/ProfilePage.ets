import { DirectTheme, DirectTypography } from '../ui/Theme';
import { DirectHaptics } from '../ui/Haptics';
import { DirectIcon, DirectIconName } from '../ui/DirectIcons';
import { DirectFlow } from '../ui/DirectFlows';
import {
  SESSION_HAS_PREMIUM,
  SESSION_DISPLAY_NAME,
  SESSION_REMAINING_DAYS,
  SESSION_LOADED
} from '../model/DirectSessionStore';

interface UtilityRowData {
  mark: string;
  title: string;
  detail: string;
  accent: boolean;
  flow: DirectFlow;
}

interface SettingsRowData {
  title: string;
  detail: string;
  flow: DirectFlow;
}

interface LegalRowData {
  title: string;
  subtitle: string;
  flow: DirectFlow;
}

/**
 * Pixel port of DirectProfilePage — hero 116, avatar 62, stats, UtilityProfileRow, settings 67, legal.
 */
@Component
export struct ProfilePage {
  onFlow: (flow: DirectFlow) => void = (_flow: DirectFlow) => {};
  @StorageProp(SESSION_HAS_PREMIUM) private hasPremium: boolean = false;
  @StorageProp(SESSION_DISPLAY_NAME) private displayName: string = '';
  @StorageProp(SESSION_REMAINING_DAYS) private remainingDays: number = 0;
  @StorageProp(SESSION_LOADED) private sessionLoaded: boolean = false;

  private readonly utilityRows: UtilityRowData[] = [
    { mark: 'BAL', title: 'Баланс', detail: '—', accent: true, flow: DirectFlow.Balance },
    { mark: 'DEV', title: 'Устройства', detail: 'Активные сеансы и лимит тарифа', accent: false, flow: DirectFlow.Devices },
    { mark: 'PAY', title: 'Платежи', detail: 'История оплат и возвратов', accent: false, flow: DirectFlow.PaymentHistory },
    { mark: 'PROMO', title: 'Промокод', detail: 'Активировать код от VPN Direct', accent: true, flow: DirectFlow.Account },
    { mark: 'HELP', title: 'Поддержка', detail: 'Оплата, вход, подписка и подключение', accent: false, flow: DirectFlow.Account },
    { mark: 'LINK', title: 'Способы входа', detail: 'Apple, email и бот — безопасная склейка', accent: false, flow: DirectFlow.AuthLogin }
  ];

  private readonly settingsRows: SettingsRowData[] = [
    { title: 'Безопасность', detail: 'Автоподключение, DNS и российские сайты', flow: DirectFlow.Security },
    { title: 'Подключение', detail: 'Протокол, failover и антиблокировка', flow: DirectFlow.Connection },
    { title: 'Диагностика', detail: 'Проверка и автоматическое исправление', flow: DirectFlow.Diagnostics },
    { title: 'Мои серверы', detail: 'Избранное и история подключений', flow: DirectFlow.Activity },
    { title: 'Системные настройки', detail: 'Ядро, туннель и служебные параметры', flow: DirectFlow.SystemSettings }
  ];

  private readonly legalRows: LegalRowData[] = [
    { title: 'Политика конфиденциальности', subtitle: 'Какие данные обрабатываются, зачем и как удаляются', flow: DirectFlow.Privacy },
    { title: 'Условия использования', subtitle: 'Правила использования приложения и сервиса', flow: DirectFlow.Legal },
    { title: 'VPN и обработка данных', subtitle: 'Обработка данных VPN‑соединения', flow: DirectFlow.Privacy },
    { title: 'О приложении', subtitle: 'VPN Direct · HarmonyOS', flow: DirectFlow.About }
  ];

  build() {
    Scroll() {
      Column() {
        Text('АККАУНТ / ALD–0248')
          .fontSize(DirectTypography.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.muted)
          .fontFamily('monospace')
          .width('100%');
        Text('Профиль')
          .fontSize(DirectTypography.pageTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(DirectTheme.ink)
          .width('100%')
          .margin({ top: 7 });
        Text('Управление приложением и безопасностью')
          .fontSize(13)
          .fontColor(DirectTheme.muted)
          .width('100%')
          .margin({ top: 4 });

        // Hero 116 — ink block with avatar 62
        Row() {
          Text(this.displayName.length > 0 ? this.displayName.substring(0, 1).toUpperCase() : 'A')
            .fontSize(30)
            .fontWeight(FontWeight.Medium)
            .fontColor(DirectTheme.acid)
            .fontFamily('monospace')
            .width(DirectTheme.profileAvatar)
            .height(DirectTheme.profileAvatar)
            .textAlign(TextAlign.Center)
            .border({ width: 1, color: '#40FFFFFF' });
          Column() {
            Text('DIRECT ACCOUNT')
              .fontSize(DirectTypography.caption)
              .fontWeight(FontWeight.Bold)
              .fontColor('#73FFFFFF')
              .fontFamily('monospace');
            Text(this.displayName.length > 0 ? this.displayName : 'Войти в Direct')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(DirectTheme.white)
              .maxLines(1)
              .margin({ top: 5 });
            Text(this.hasPremium ? `${this.remainingDays} дн. · Активна` : 'Оплата и вход')
              .fontSize(10)
              .fontColor('#80FFFFFF')
              .maxLines(1)
              .margin({ top: 5 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 16 });
          DirectIcon({
            name: DirectIconName.ArrowUpRight,
            iconSize: 14,
            color: DirectTheme.acid,
            weight: 1.6
          });
        }
          .width('100%')
          .height(DirectTheme.profileHeroHeight)
          .padding({ left: 16, right: 16 })
          .backgroundColor(DirectTheme.ink)
          .margin({ top: 28 })
          .onClick(() => {
            DirectHaptics.selection();
            this.onFlow(this.displayName.length > 0 ? DirectFlow.Management : DirectFlow.AuthLogin);
          });

        // Stats strip 76
        Row() {
          this.profileStat('ПОДПИСОК', this.hasPremium ? '01' : '00');
          this.profileStat('УСТРОЙСТВ', '01');
          this.profileStat('ЗАЩИЩЕНО', this.hasPremium ? `${this.remainingDays}д` : '00:00');
        }
          .width('100%')
          .height(DirectTheme.profileStatHeight)
          .border({ width: { bottom: 1 }, color: DirectTheme.line });

        this.sectionHeader('01', 'АККАУНТ');
        ForEach(this.utilityRows, (row: UtilityRowData) => {
          this.utilityRow(row);
        });

        this.sectionHeader('02', 'НАСТРОЙКИ');
        Column() {
          ForEach(this.settingsRows, (row: SettingsRowData, index: number) => {
            this.settingsRow(row, index + 1);
          });
        }.width('100%').margin({ top: 5 });

        this.sectionHeader('03', 'ЮРИДИЧЕСКАЯ ИНФОРМАЦИЯ');
        Column() {
          ForEach(this.legalRows, (row: LegalRowData) => {
            this.legalRow(row);
          });
        }.width('100%').margin({ top: 5 });

        Blank().height(28);
      }
        .width('100%')
        .padding({
          left: DirectTheme.pageHorizontal,
          right: DirectTheme.pageHorizontal,
          top: DirectTheme.pageTop,
          bottom: 24
        });
    }.scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder
  profileStat(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(DirectTypography.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.muted)
        .fontFamily('monospace');
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.ink)
        .fontFamily('monospace')
        .margin({ top: 7 })
        .maxLines(1);
    }
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 12 })
      .border({ width: { left: 1 }, color: DirectTheme.line });
  }

  @Builder
  sectionHeader(number: string, title: string) {
    Row() {
      Text(number)
        .fontSize(DirectTypography.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.ink)
        .fontFamily('monospace');
      Text(title)
        .fontSize(DirectTypography.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.ink)
        .fontFamily('monospace')
        .margin({ left: 8 });
      Blank();
    }
      .width('100%')
      .height(36)
      .margin({ top: 18 })
      .border({ width: { top: 1 }, color: DirectTheme.ink });
  }

  @Builder
  utilityRow(row: UtilityRowData) {
    Row() {
      Text(row.mark)
        .fontSize(8)
        .fontWeight(FontWeight.Bold)
        .fontColor(row.accent ? DirectTheme.acid : DirectTheme.ink)
        .fontFamily('monospace')
        .width(42)
        .height(42)
        .textAlign(TextAlign.Center)
        .backgroundColor(row.accent ? DirectTheme.ink : DirectTheme.fieldFill)
        .border({ width: row.accent ? 0 : 1, color: DirectTheme.line });
      Column() {
        Text(row.title).fontSize(13).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
        Text(row.detail).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 });
      DirectIcon({
        name: DirectIconName.ArrowUpRight,
        iconSize: 11,
        color: DirectTheme.ink,
        weight: 1.5
      });
    }
      .width('100%')
      .constraintSize({ minHeight: DirectTheme.utilityRowMin })
      .border({ width: { bottom: 1 }, color: DirectTheme.line })
      .onClick(() => {
        DirectHaptics.selection();
        this.onFlow(row.flow);
      });
  }

  @Builder
  settingsRow(row: SettingsRowData, index: number) {
    Row() {
      Text(String(index).padStart(2, '0'))
        .fontSize(DirectTypography.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(DirectTheme.muted)
        .fontFamily('monospace');
      Column() {
        DirectIcon({ name: DirectIconName.ChevronRight, iconSize: 11, color: DirectTheme.muted, weight: 1.5 });
      }.width(23).alignItems(HorizontalAlign.Center).margin({ left: 13 });
      Column() {
        Text(row.title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).maxLines(1);
        Text(row.detail).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }).maxLines(2);
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 13 });
      DirectIcon({
        name: DirectIconName.ArrowRight,
        iconSize: 11,
        color: DirectTheme.ink,
        weight: 1.5
      });
    }
      .width('100%')
      .height(DirectTheme.profileSettingsRow)
      .border({ width: { bottom: 1 }, color: DirectTheme.line })
      .onClick(() => {
        DirectHaptics.selection();
        this.onFlow(row.flow);
      });
  }

  @Builder
  legalRow(row: LegalRowData) {
    Row() {
      Column() {
        DirectIcon({ name: DirectIconName.ArrowUpRight, iconSize: 11, color: DirectTheme.muted, weight: 1.5 });
      }.width(23).alignItems(HorizontalAlign.Center);
      Column() {
        Text(row.title).fontSize(13).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink);
        Text(row.subtitle).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 13 });
      DirectIcon({
        name: DirectIconName.ArrowUpRight,
        iconSize: 11,
        color: DirectTheme.muted,
        weight: 1.5
      });
    }
      .width('100%')
      .constraintSize({ minHeight: 62 })
      .border({ width: { bottom: 1 }, color: DirectTheme.line })
      .onClick(() => {
        DirectHaptics.selection();
        this.onFlow(row.flow);
      });
  }
}
