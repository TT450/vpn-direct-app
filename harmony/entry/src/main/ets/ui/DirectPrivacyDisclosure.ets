import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectIcon, DirectIconName } from './DirectIcons';

@Component
export struct DirectPrivacyDisclosure {
  onAccept: () => void = () => {};
  onDecline: () => void = () => {};

  build() {
    Stack() {
      Column() {
        Row() {
          Column() {
            Text('VPN DIRECT').fontSize(14).fontWeight(FontWeight.Bold).fontColor(DirectTheme.white).fontFamily('monospace');
            Text('PRIVACY DISCLOSURE / 5.4').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace').margin({ top: 2 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Text('REQUIRED').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').padding({ left: 8, right: 8, top: 6, bottom: 6 }).border({ width: 1, color: '#A6F069AA' });
        }.width('100%').height(62).padding({ left: 20, right: 20 }).border({ width: { bottom: 1 }, color: '#24FFFFFF' });

        Scroll() {
          Column() {
            Text('ПЕРЕД ПОДКЛЮЧЕНИЕМ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width('100%');
            Text('VPN DIRECT И ВАША ПРИВАТНОСТЬ').fontSize(24).fontWeight(FontWeight.Bold).fontColor(DirectTheme.white).fontFamily('monospace').width('100%').margin({ top: 18 });
            Text('VPN Direct создаёт системное VPN‑подключение и направляет сетевой трафик через выбранный маршрут. Перед первым использованием мы обязаны ясно объяснить, какие данные обрабатываются и для чего.')
              .fontSize(13).fontColor('#C7FFFFFF').width('100%').margin({ top: 18 });
            this.block('01', 'ЧТО МЫ НЕ СОБИРАЕМ', 'Мы не записываем содержимое вашего трафика, историю посещённых сайтов или DNS‑запросы и не используем VPN‑активность для рекламного профилирования.');
            this.block('02', 'ЧТО МОЖЕТ ОБРАБАТЫВАТЬСЯ', 'Для работы аккаунта, подписки и поддержки могут обрабатываться необходимые служебные сведения — например идентификатор аккаунта, данные подписки и платежа. Подробный перечень и сроки хранения указаны в Политике конфиденциальности.');
            this.block('03', 'КАК ИСПОЛЬЗУЮТСЯ ДАННЫЕ', 'Данные используются для работы сервиса, выдачи и обслуживания доступа, поддержки и выполнения обязательных юридических требований. Данные, полученные через VPN‑соединение, не продаются, не используются для рекламы и не раскрываются третьим лицам.');
            Text('ДОКУМЕНТЫ').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace').width('100%').margin({ top: 2, bottom: 8 });
            this.document('Политика конфиденциальности');
            this.document('Условия использования');
            this.document('EULA');
            this.document('Тарифы и условия сервиса');
            Text('Нажимая «СОГЛАСИТЬСЯ», вы подтверждаете, что ознакомились с этим уведомлением и разрешаете VPN Direct использовать системное VPN‑подключение на этом устройстве.')
              .fontSize(10).fontWeight(FontWeight.Medium).fontColor('#7AFFFFFF').fontFamily('monospace').width('100%').margin({ top: 18, bottom: 22 });
          }.padding({ left: 20, right: 20, top: 22, bottom: 22 });
        }.scrollBar(BarState.Auto).layoutWeight(1).width('100%');

        Row() {
          Text('ОТКАЗАТЬСЯ').fontSize(10).fontWeight(FontWeight.Bold).fontColor('#AEFFFFFF').fontFamily('monospace').layoutWeight(1).height(54).textAlign(TextAlign.Center)
            .onClick(() => { DirectHaptics.error(); this.onDecline(); });
          Row({ space: 7 }) {
            Text('СОГЛАСИТЬСЯ').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace');
            DirectIcon({ name: DirectIconName.Checkmark, iconSize: 10, color: DirectTheme.ink, weight: 1.8 });
          }.layoutWeight(1).height(54).justifyContent(FlexAlign.Center).backgroundColor(DirectTheme.acid)
            .onClick(() => { DirectHaptics.success(); this.onAccept(); });
        }.width('100%').border({ width: { top: 1 }, color: '#24FFFFFF' });
      }.width('100%').height('100%').backgroundColor(DirectTheme.ink).border({ width: 1, color: '#B8F069B8' });
      Row().width('100%').height(3).backgroundColor(DirectTheme.acid);
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 54, bottom: 54 }).backgroundColor('#38000000');
  }

  @Builder private block(index: string, title: string, body: string) {
    Row() {
      Text(index).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace').width(22);
      Column() { Text(title).fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.white).fontFamily('monospace'); Text(body).fontSize(12).fontColor('#A8FFFFFF').width('100%').margin({ top: 6 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
    }.width('100%').padding({ top: 12 }).border({ width: { top: 1 }, color: '#1AFFFFFF' });
  }

  @Builder private document(title: string) {
    Row() {
      Text(title).fontSize(11).fontWeight(FontWeight.Medium).fontColor(DirectTheme.acid).layoutWeight(1);
      DirectIcon({ name: DirectIconName.ArrowUpRight, iconSize: 9, color: DirectTheme.acid, weight: 1.5 });
    }.width('100%').constraintSize({ minHeight: 36 }).padding({ left: 12, right: 12 }).border({ width: 1, color: '#24141714' });
  }
}
