# Local secrets (never commit)

Copy to your shell profile or a local untracked env file:

```bash
export FASTLANE_TEAM_ID="YOUR_APPLE_TEAM_ID"
export ASC_KEY_ID="YOUR_ASC_KEY_ID"
export ASC_ISSUER_ID="YOUR_ASC_ISSUER_UUID"
export ASC_KEY_PATH="$PWD/fastlane/AuthKey_XXXXXX.p8"   # gitignored
export APP_STORE_APP_ID="YOUR_NUMERIC_APP_ID"           # optional
export DEVELOPMENT_TEAM="$FASTLANE_TEAM_ID"
```

Place the App Store Connect `.p8` under `fastlane/` (matched by `*.p8` in `.gitignore`).
