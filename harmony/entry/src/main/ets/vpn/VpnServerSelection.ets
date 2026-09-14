export interface SelectedVpnServer {
  id: string;
  displayName: string;
}

export class VpnServerSelection {
  private static current: SelectedVpnServer = { id: 'auto', displayName: 'Авто' };

  static get(): SelectedVpnServer {
    return VpnServerSelection.current;
  }

  static set(server: SelectedVpnServer): void {
    VpnServerSelection.current = server;
  }
}
