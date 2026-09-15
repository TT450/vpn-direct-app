import { vibrator } from '@kit.SensorServiceKit';

export enum DirectHapticEvent {
  TouchDown, TouchUp, Navigation, Selection, ToggleOn, ToggleOff, ServerSelected,
  SheetPresented, SheetDismissed, Warning, Error, RefreshCompleted, VPNConnecting,
  VPNConnected, VPNDisconnecting, VPNDisconnected, VPNSwitching, VPNSwitched, PurchaseCompleted
}

export class DirectHaptics {
  private static lastAt: number = 0;

  static play(event: DirectHapticEvent | string): void {
    const now: number = Date.now();
    if (now - DirectHaptics.lastAt < 35) return;
    DirectHaptics.lastAt = now;
    let resolved: DirectHapticEvent = DirectHapticEvent.Selection;
    if (typeof event === 'string') {
      resolved = event === 'error' ? DirectHapticEvent.Error : DirectHapticEvent.PurchaseCompleted;
    } else {
      resolved = event;
    }
    let effectId: string = 'haptic.effect.soft';
    switch (resolved) {
      case DirectHapticEvent.Warning: effectId = 'haptic.notice.warning'; break;
      case DirectHapticEvent.Error: effectId = 'haptic.notice.fail'; break;
      case DirectHapticEvent.VPNConnected:
      case DirectHapticEvent.VPNSwitched:
      case DirectHapticEvent.PurchaseCompleted:
      case DirectHapticEvent.RefreshCompleted: effectId = 'haptic.notice.success'; break;
      case DirectHapticEvent.ToggleOn:
      case DirectHapticEvent.ServerSelected:
      case DirectHapticEvent.VPNConnecting: effectId = 'haptic.effect.hard'; break;
      case DirectHapticEvent.ToggleOff:
      case DirectHapticEvent.VPNDisconnected: effectId = 'haptic.effect.sharp'; break;
      default: effectId = 'haptic.effect.soft';
    }
    vibrator.isSupportEffect(effectId).then((supported: boolean) => {
      if (!supported) return;
      vibrator.startVibration({ type: 'preset', effectId, count: 1 }, { usage: 'unknown' }).catch(() => {});
    }).catch(() => {});
  }

  static navigation(): void { DirectHaptics.play(DirectHapticEvent.Navigation); }
  static selection(): void { DirectHaptics.play(DirectHapticEvent.Selection); }
  static success(): void { DirectHaptics.play(DirectHapticEvent.PurchaseCompleted); }
  static error(): void { DirectHaptics.play(DirectHapticEvent.Error); }
}
