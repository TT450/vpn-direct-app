import nativeCore from 'libvpndirect_core.so';

/**
 * Thin ArkTS ↔ native boundary.
 *
 * The native module returns an integer status code. Keep that ABI explicit so
 * a failed Core start/stop cannot be mistaken for a successful operation.
 * The native side must expose the pinned VPN Direct Core only; it must never
 * download or replace executable code.
 */
export class HarmonyCoreBridge {
  async start(tunFd: number, profileJson: string): Promise<void> {
    const rc = nativeCore.start(tunFd, profileJson) as number;
    if (rc !== 0) {
      throw new Error(`VPN Direct Core start failed: ${rc}`);
    }
  }

  async stop(): Promise<void> {
    const rc = nativeCore.stop() as number;
    if (rc !== 0) {
      throw new Error(`VPN Direct Core stop failed: ${rc}`);
    }
  }
}
