import { vibrator } from '@kit.SensorServiceKit';

/**
 * HarmonyOS counterpart of the iOS HapticManager semantic vocabulary.
 * UI code calls semantic events; platform-specific motor implementation stays here.
 */
export enum DirectHapticEvent {
  TouchDown,
  TouchUp,
  Navigation,
  Selection,
  ToggleOn,
  ToggleOff,
  ServerSelected,
  SheetPresented,
  SheetDismissed,
  Warning,
  Error,
  RefreshCompleted,
  VPNConnecting,
  VPNConnected,
  VPNDisconnecting,
  VPNDisconnected,
  VPNSwitching,
  VPNSwitched,
  PurchaseCompleted
}

export class DirectHaptics {
  private static lastAt: number = 0;

  static play(event: DirectHapticEvent): void {
    const now = Date.now();
    if (now - DirectHaptics.lastAt < 35) return;
    DirectHaptics.lastAt = now;

    let effectId: string = 'haptic.effect.soft';
    switch (event) {
      case DirectHapticEvent.Warning:
        effectId = 'haptic.notice.warning';
        break;
      case DirectHapticEvent.Error:
        effectId = 'haptic.notice.fail';
        break;
      case DirectHapticEvent.VPNConnected:
      case DirectHapticEvent.VPNSwitched:
      case DirectHapticEvent.PurchaseCompleted:
      case DirectHapticEvent.RefreshCompleted:
        effectId = 'haptic.notice.success';
        break;
      case DirectHapticEvent.ToggleOn:
      case DirectHapticEvent.ServerSelected:
      case DirectHapticEvent.VPNConnecting:
        effectId = 'haptic.effect.hard';
        break;
      case DirectHapticEvent.ToggleOff:
      case DirectHapticEvent.VPNDisconnected:
        effectId = 'haptic.effect.sharp';
        break;
      default:
        effectId = 'haptic.effect.soft';
    }

    try {
      vibrator.isSupportEffect(effectId).then((supported: boolean) => {
        if (!supported) return;
        vibrator.startVibration({
          type: 'preset',
          effectId: effectId,
          count: 1
        }, {
          usage: 'unknown'
        }).catch(() => {});
      }).catch(() => {});
    } catch (_) {
      // Haptics are best-effort and must never affect VPN/UI behavior.
    }
  }
}
