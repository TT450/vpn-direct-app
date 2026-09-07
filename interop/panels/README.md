# Panel interop labs

Runnable Docker / install scaffolds per panel for battle-key qualification and subscription export into `tests/fixtures/panels/<panel>/`.

```text
interop/panels/<panel>/
  README.md
  VERSION
  docker-compose.yml   # or install notes when Docker is impractical
  .env.example
  run.sh               # echoes how to export subscription
  evidence/.gitkeep
```

Admin APIs are for **lab automation only** — not iOS runtime clients.

Scaffolds present for all 12 panels:

| Panel | Path |
| --- | --- |
| remnawave | `interop/panels/remnawave/` |
| 3x-ui | `interop/panels/3x-ui/` |
| x-ui | `interop/panels/x-ui/` |
| tx-ui | `interop/panels/tx-ui/` |
| marzban | `interop/panels/marzban/` |
| marzneshin | `interop/panels/marzneshin/` |
| pasarguard | `interop/panels/pasarguard/` |
| hiddify | `interop/panels/hiddify/` |
| libertea | `interop/panels/libertea/` |
| s-ui | `interop/panels/s-ui/` |
| wg-easy | `interop/panels/wg-easy/` |
| amnezia | `interop/panels/amnezia/` |

Do **not** mark `core/panel-compatibility.json` status `tested` or PROTOCOL_MATRIX rows without files under `evidence/` plus device qualification.
