# Interop lab

Runnable templates for battle-key qualification. Fixtures under `tests/fixtures/regression/` stay secret-free.

**Never** commit real battle keys. Inject via env (see each family `run.sh`).

| Family | Path | Status |
| --- | --- | --- |
| Xray | [`xray/`](xray/) | runnable template |
| Hysteria | [`hysteria/`](hysteria/) | runnable template |
| Amnezia | [`amnezia/`](amnezia/) | runnable template |
| Mieru | [`mieru/`](mieru/) | runnable template (Core `with_mieru`) |
| TUIC / AnyTLS / MASQUE | scaffolds | README-only until needed |

Attach evidence under each `evidence/` directory before flipping PROTOCOL_MATRIX Interop / Status to `tested`.

Device checklist: [`docs/device/IPHONE_QUALIFICATION.md`](../docs/device/IPHONE_QUALIFICATION.md).

## Quick start

```bash
cd interop/xray
export BATTLE_UUID=... BATTLE_PBK=... BATTLE_SID=... BATTLE_SNI=... BATTLE_HOST=...
./run.sh
```

Interop=`planned` in the matrix is intentional until you commit evidence files after a live run.
