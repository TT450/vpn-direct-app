export interface SelectedVpnServer {
  id: string;
  displayName: string;
  countryCode: string;
}

export class VpnServerSelection {
  private static current: SelectedVpnServer = { id: 'auto', displayName: 'Авто', countryCode: '' };

  static get(): SelectedVpnServer {
    return VpnServerSelection.current;
  }

  static set(server: SelectedVpnServer): void {
    VpnServerSelection.current = server;
  }
}
