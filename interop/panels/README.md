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

Scaffolds present for: remnawave, 3x-ui, marzban, marzneshin, pasarguard, hiddify, s-ui, libertea.

Do **not** mark `core/panel-compatibility.json` status `tested` or PROTOCOL_MATRIX rows without files under `evidence/` plus device qualification.
