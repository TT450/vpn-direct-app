import nativeCore from 'libvpndirect_core.so';

/** Thin ArkTS ↔ native boundary. The native side must expose the pinned
 * VPN Direct Core only; it must never download or replace executable code. */
export class HarmonyCoreBridge {
  start(tunFd: number, profileJson: string): Promise<void> {
    return Promise.resolve().then(() => {
      nativeCore.start(tunFd, profileJson);
    });
  }

  stop(): Promise<void> {
    return Promise.resolve().then(() => {
      nativeCore.stop();
    });
  }
}
