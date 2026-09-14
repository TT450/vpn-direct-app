import nativeCore from 'libvpndirect_core.so';

export class HarmonyCoreBridge {
  start(tunFd: number, profileJson: string): boolean {
    const rc: number = nativeCore.start(tunFd, profileJson) as number;
    if (rc !== 0) {
      console.error(`VPN Direct Core start failed: ${rc}`);
      return false;
    }
    return true;
  }

  stop(): boolean {
    const rc: number = nativeCore.stop() as number;
    if (rc !== 0) {
      console.error(`VPN Direct Core stop failed: ${rc}`);
      return false;
    }
    return true;
  }
}
