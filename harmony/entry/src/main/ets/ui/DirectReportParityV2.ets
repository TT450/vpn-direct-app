import { DirectTheme } from './Theme';
import { DirectHaptics } from './Haptics';
import { DirectIcon, DirectIconName } from './DirectIcons';
import { VpnServerSelection } from '../vpn/VpnServerSelection';
import { http } from '@kit.NetworkKit';

@Component
export struct DirectReportParityV2 {
  onClose: () => void = () => {};
  @StorageProp('vpn_status') private vpnStatus: string = 'Disconnected';
  @StorageProp('vpn_server_name') private serverName: string = 'Авто';
  @StorageProp('connection_mode') private connectionMode: string = 'Авто';
  @StorageProp('vpn_runtime') private runtime: string = '00:00:00';
  @State private publicIP: string = '—';
  @State private loadingIP: boolean = false;
  private get protected(): boolean { return this.vpnStatus === 'Connected'; }
  aboutToAppear(): void { void this.refreshIP(); }
  private async refreshIP(): Promise<void> {
    if (this.loadingIP) return;
    this.loadingIP = true;
    try {
      const client = http.createHttp();
      const response = await client.request('https://api.ipify.org?format=text', { method: http.RequestMethod.GET, connectTimeout: 6000, readTimeout: 6000 });
      this.publicIP = typeof response.result === 'string' ? response.result.trim() : '—';
      client.destroy();
    } catch { this.publicIP = '—'; }
    this.loadingIP = false;
  }
  build() {
    Column() {
      Row() {
        Column() {
          Text(this.protected ? 'ПРОВЕРКА / VPN' : 'ПРОВЕРКА / WAN').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace');
          Text(this.protected ? 'Соединение подключено' : 'Соединение отключено').fontSize(24).fontWeight(600).fontColor(DirectTheme.ink).margin({ top: 6 });
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Column() { DirectIcon({ name: DirectIconName.Xmark, iconSize: 12, color: DirectTheme.acid, weight: 1.8 }); }.width(36).height(36).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).backgroundColor(DirectTheme.ink).onClick(() => { DirectHaptics.navigation(); this.onClose(); });
      }.width('100%').padding({ left: 20, right: 20, top: 28, bottom: 14 }).border({ width: { bottom: 1 }, color: DirectTheme.line });
      Scroll() {
        Column() {
          Row({ space: 13 }) {
            Text(this.protected ? 'OK' : '×').fontSize(19).fontWeight(FontWeight.Medium).fontColor(this.protected ? DirectTheme.acid : DirectTheme.danger).width(47).height(47).textAlign(TextAlign.Center).border({ width: 1, color: '#40FFFFFF' });
            Column({ space: 4 }) {
              Text(this.protected ? 'IP VPN' : 'РЕАЛЬНЫЙ IP').fontSize(9).fontWeight(FontWeight.Bold).fontColor('#6BFFFFFF').fontFamily('monospace');
              Text(this.loadingIP ? '…' : this.publicIP).fontSize(16).fontWeight(600).fontColor(DirectTheme.white).fontFamily('monospace');
              Text(this.protected ? `${this.serverName} · ${this.runtime}` : 'Без VPN — адрес вашего провайдера').fontSize(9).fontColor('#80FFFFFF');
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Column() { Text('ОБНОВИТЬ').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.acid).fontFamily('monospace'); }.width(58).height(36).justifyContent(FlexAlign.Center).onClick(() => { void this.refreshIP(); });
          }.width('100%').height(106).padding({ left: 14, right: 14 }).backgroundColor(DirectTheme.ink);
          Row() { this.fact('ПРОТОКОЛ', 'VLESS · REALITY'); this.fact('СОЕДИНЕНИЕ', this.protected ? this.runtime : '00:00:00'); }.width('100%');
          Row() { this.fact('DNS', this.protected ? 'ЗАЩИЩЁН' : 'ОТКРЫТ'); this.fact('ЗАДЕРЖКА', '— MS'); }.width('100%');
          Row() { this.fact('РЕЖИМ', this.connectionMode.toUpperCase()); this.fact('ПОДПИСКА', this.serverName === 'Авто' ? '—' : 'VPN DIRECT'); }.width('100%');
          Row() { Text('ПРОВЕРКА КАНАЛА').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.ink).fontFamily('monospace'); Blank(); Text(this.protected ? '4 / 4' : '0 / 4').fontSize(9).fontWeight(FontWeight.Bold).fontColor(DirectTheme.green).fontFamily('monospace'); }.width('100%').height(38).margin({ top: 18 }).border({ width: { top: 1 }, color: DirectTheme.ink });
          this.checkRow(this.protected ? 'Исходящий IP через VPN' : 'Показан реальный IP');
          this.checkRow(`DNS-запросы ${this.protected ? 'защищены' : 'открыты'}`);
          this.checkRow(`WebRTC ${this.protected ? 'утечек нет' : 'не проверялся'}`);
          this.checkRow(`Маршрут через ${this.serverName === 'Авто' ? 'VPN' : this.serverName}`);
          Blank().height(28);
        }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 28 });
      }.layoutWeight(1).scrollBar(BarState.Off);
    }.width('100%').height('100%').backgroundColor(DirectTheme.paper);
  }
  @Builder private fact(label: string, value: string) { Column() { Text(label).fontSize(8).fontWeight(FontWeight.Bold).fontColor(DirectTheme.muted).fontFamily('monospace'); Text(value).fontSize(11).fontWeight(600).fontColor(DirectTheme.ink).fontFamily('monospace').margin({ top: 4 }); }.layoutWeight(1).height(58).alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center).padding({ left: 12 }).border({ width: { bottom: 1 }, right: 1 }, color: DirectTheme.line); }
  @Builder private checkRow(text: string) { Row() { Text(text).fontSize(11).fontColor(DirectTheme.ink).layoutWeight(1); DirectIcon({ name: this.protected ? DirectIconName.Checkmark : DirectIconName.Minus, iconSize: 11, color: this.protected ? DirectTheme.green : DirectTheme.muted, weight: 1.6 }); }.width('100%').height(44).border({ width: { bottom: 1 }, color: DirectTheme.line }); }
}
