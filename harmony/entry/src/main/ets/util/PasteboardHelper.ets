import { pasteboard } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

/**
 * Utility to read text from the system pasteboard.
 * Requires ohos.permission.READ_PASTEBOARD declared in module.json5.
 * Supports runtime permission request on HarmonyOS NEXT.
 */
export class PasteboardHelper {
  /**
   * Request READ_PASTEBOARD permission at runtime.
   * Returns true if permission is now granted; false if denied or unavailable.
   */
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Permissions[] = ['ohos.permission.READ_PASTEBOARD'];
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      return Array.isArray(result.authResults) && result.authResults[0] === 0;
    } catch (err) {
      console.warn(`PasteboardHelper: permission request failed: ${err}`);
      return false;
    }
  }

  /**
   * Read text from pasteboard without requesting permission first.
   * Throws with a descriptive message on permission error.
   */
  static async readText(): Promise<string> {
    return PasteboardHelper.readTextImpl();
  }

  /**
   * Request READ_PASTEBOARD permission, then read text.
   * Should be called from a UI component that has a UIAbilityContext.
   */
  static async readTextWithContext(context: common.UIAbilityContext): Promise<string> {
    await PasteboardHelper.requestPermission(context);
    return PasteboardHelper.readTextImpl();
  }

  private static async readTextImpl(): Promise<string> {
    const pb: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();

    // Get data directly — do NOT gate on hasData() because some devices report
    // false for hasData() even when the pasteboard contains text.
    let pasteData: pasteboard.PasteData | null = null;
    try {
      pasteData = await pb.getData();
    } catch (err) {
      const code = (err as Record<string, number>)['code'] ?? 0;
      if (code === 201 || code === 12100002 || code === 12100001) {
        throw new Error('Нет разрешения на чтение буфера обмена. Разрешите доступ в системных настройках приложения.');
      }
      // Other error — rethrow so UI can display it
      const msg = err instanceof Error ? err.message : `${err}`;
      throw new Error(msg.length > 0 ? msg : 'Не удалось прочитать буфер обмена');
    }

    if (pasteData === null) {
      return '';
    }

    // Primary: plain text
    try {
      const text = pasteData.getPrimaryText();
      if (typeof text === 'string' && text.trim().length > 0) {
        return text.trim();
      }
    } catch { /* ignore */ }

    // Fallback 1: HTML content (strip tags)
    try {
      const html = pasteData.getPrimaryHtml();
      if (typeof html === 'string' && html.length > 0) {
        const stripped = html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
        if (stripped.length > 0) {
          return stripped;
        }
      }
    } catch { /* ignore */ }

    // Fallback 2: URI
    try {
      const uri = pasteData.getPrimaryUri();
      if (typeof uri === 'string' && uri.length > 0) {
        return uri.trim();
      }
    } catch { /* ignore */ }

    return '';
  }
}
