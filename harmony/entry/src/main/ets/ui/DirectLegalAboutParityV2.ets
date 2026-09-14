import { DirectTheme, DirectTypography } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectFlow } from './DirectFlowModel';

@Component
export struct DirectLegalAboutParityV2 {
  @Prop flow: DirectFlow = DirectFlow.Legal;
  onClose: () => void = () => {};

  private readonly docs: string[][] = [
    ['Политика конфиденциальности', 'Какие данные обрабатываются, зачем и как удаляются'],
    ['Условия использования', 'Правила использования приложения и сервиса'],
    ['EULA', 'Стандартное лицензионное соглашение App Store'],
    ['VPN и обработка данных', 'Обработка данных VPN-соединения и ограничения их использования'],
    ['Тарифы и условия сервиса', 'Стоимость и условия предоставления VPN-ресурса'],
    ['Возврат App Store', 'Запрос возврата платежа, проведённого через Apple'],
    ['Лицензия открытого кода', 'Лицензионные условия исходного кода приложения'],
    ['Уведомления о компонентах', 'Third-party notices и сведения о сторонних компонентах']
  ];

  build() {
    Scroll() { Column() { this.header(); if (this.flow === DirectFlow.Privacy) this.privacy(); else if (this.flow === DirectFlow.About) this.about(); else this.legal(); }.width('100%').padding({ left: 20, right: 20, bottom: 28 }); }
      .scrollBar(BarState.Off).width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }

  @Builder private header() {
    Row() {
      Column() {
        Text(this.flow === DirectFlow.Privacy ? 'DIRECT / PRIVACY' : this.flow === DirectFlow.About ? 'DIRECT / ABOUT' : 'DIRECT / LEGAL').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
        Text(this.flow === DirectFlow.Privacy ? 'Конфиденциальность' : this.flow === DirectFlow.About ? 'О приложении' : 'Правовая информация').fontSize(DirectTypography.pageTitle).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 6 });
        Text(this.flow === DirectFlow.Privacy ? 'Данные VPN-соединения и пользовательский контроль' : this.flow === DirectFlow.About ? 'Версия, ядро и сведения о VPN Direct' : 'Документы и сведения о сервисе').fontSize(13).fontColor(DirectTheme.muted).margin({ top: 7 });
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Text('×').fontSize(18).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onClose(); });
    }.width('100%').padding({ top: 28, bottom: 14 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
  }

  @Builder private legal() {
    Row() { Text('ДОКУМЕНТЫ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text('08').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(36).border({ width: { top: 1 }, color: DirectTheme.ink }).margin({ top: 18 });
    ForEach(this.docs, (doc: string[], index: number) => {
      Row() { Text(String(index + 1).padStart(2, '0')).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace').width(25); Column() { Text(doc[0]).fontSize(14).fontWeight(600).fontColor(DirectTheme.ink); Text(doc[1]).fontSize(10).fontColor(DirectTheme.muted).margin({ top: 4 }).maxLines(2); }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 13 }); Text('↗').fontSize(10).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted); }.width('100%').constraintSize({ minHeight: 67 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
    });
  }

  @Builder private privacy() {
    this.section('PRIVACY DISCLOSURE', '5.4');
    Text('VPN Direct использует сетевое соединение только для предоставления выбранного VPN-сервиса. Перед первым подключением пользователь явно подтверждает раскрытие информации о сетевых данных и обработке соединения.').fontSize(12).fontColor(DirectTheme.ink).lineSpacing(4).margin({ top: 14 });
    this.section('КОНТРОЛЬ', 'USER');
    Text('Пользователь может отказаться от подключения, удалить аккаунт и обратиться к политике конфиденциальности. Приложение не должно показывать фиктивные сведения о сервере, балансе или платеже, если backend не подключён.').fontSize(12).fontColor(DirectTheme.ink).lineSpacing(4).margin({ top: 14 });
  }

  @Builder private about() {
    this.section('О ПРИЛОЖЕНИИ', 'VPN DIRECT');
    this.info('НАЗВАНИЕ', 'VPN Direct');
    this.info('ПЛАТФОРМА', 'HarmonyOS');
    this.info('VPN ENGINE', 'HarmonyOS VPN Extension · Packet Tunnel');
    this.info('ЯДРО', 'VPN Direct Core · sing-box');
    this.section('СОСТОЯНИЕ', 'NATIVE');
    Text('Версия и фактическая версия ядра должны поступать из сборки/bridge, а не из статической имитации.').fontSize(10).fontColor(DirectTheme.muted).lineSpacing(3).margin({ top: 12 });
  }

  @Builder private section(label: string, meta: string) { Row() { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text(meta).fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(38).border({ width: { top: 1 }, color: DirectTheme.ink }).margin({ top: 20 }); }
  @Builder private info(label: string, value: string) { Row() { Text(label).fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace').width(84); Text(value).fontSize(11).fontWeight(500).fontColor(DirectTheme.white).fontFamily('monospace').layoutWeight(1); }.width('100%').constraintSize({ minHeight: 44 }).padding({ left: 12, right: 12 }).backgroundColor(DirectTheme.panel).border({ width: { bottom: 1 }, color: '#1AFFFFFF' }); }
}
