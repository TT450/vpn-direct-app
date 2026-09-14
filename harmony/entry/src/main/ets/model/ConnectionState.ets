export enum ConnectionStatus {
  Disconnected = 'disconnected',
  Connecting = 'connecting',
  Connected = 'connected',
  Disconnecting = 'disconnecting',
  Failed = 'failed'
}

export class ConnectionState {
  status: ConnectionStatus = ConnectionStatus.Disconnected;
  statusTitle: string = 'VPN отключён';
  statusSubtitle: string = 'Подключение не активно';
  serverName: string = 'Авто';
  serverPing: string = '— MS';
  connectionMode: string = 'Авто';
  isProtected: boolean = false;

  reset(): void {
    this.status = ConnectionStatus.Disconnected;
    this.statusTitle = 'VPN отключён';
    this.statusSubtitle = 'Подключение не активно';
    this.isProtected = false;
  }

  setConnecting(): void {
    this.status = ConnectionStatus.Connecting;
    this.statusTitle = 'Подключение';
    this.statusSubtitle = 'Создаём защищённое соединение';
    this.isProtected = false;
  }

  setConnected(): void {
    this.status = ConnectionStatus.Connected;
    this.statusTitle = 'VPN подключён';
    this.statusSubtitle = 'Соединение активно';
    this.isProtected = true;
  }

  setDisconnecting(): void {
    this.status = ConnectionStatus.Disconnecting;
    this.statusTitle = 'Отключение';
    this.statusSubtitle = 'Завершаем соединение';
    this.isProtected = false;
  }

  setFailed(message: string = 'Не удалось подключиться'): void {
    this.status = ConnectionStatus.Failed;
    this.statusTitle = 'Ошибка подключения';
    this.statusSubtitle = message;
    this.isProtected = false;
  }
}
