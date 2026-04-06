# Release Pipeline (TR)

## 1) Workflow

Manuel release candidate workflow:

1. `.github/workflows/release_candidate.yml`
2. Trigger: `workflow_dispatch` (`release_tag` input)
3. Opsiyonel strict gate: `require_approvals = true`
4. Opsiyonel strict gate: `require_release_ops_complete = true`

## 2) Neler Yapiyor?

1. Preflight validation:
   - rights registry
   - paywall product mapping
   - app store localized metadata
   - release ops registry
   - localization validation
2. Vaccine package build
3. iOS release build smoke (no codesign)
4. RC artifact upload
5. `docs/RELEASE_READINESS_REPORT.md` uretimi
6. `docs/RELEASE_OPS_ACTION_BOARD_TR.md` uretimi
7. `docs/APP_STORE_LOCALIZATION_UPLOAD_SHEET_TR.md` uretimi
8. `docs/CLOSURE_PLAYBOOK_TR.md` uretimi
9. Opsiyonel: `upload_testflight=true` ile imzali archive + TestFlight upload

## 3) Kalan (Tam Production Release Icin)

1. Apple code signing + provisioning pipeline
2. CI tarafinda otomatik TestFlight upload adimi (yerel CLI mevcut)
3. Backend deploy ortamina otomatik rollout
4. Rollback otomasyonu

## 4) Yerel TestFlight Komutu

```bash
cd app/ios
ASC_API_KEY_ID="<APP_STORE_CONNECT_KEY_ID>" \
ASC_API_ISSUER_ID="<APP_STORE_CONNECT_ISSUER_ID>" \
ASC_P8_FILE_PATH="/absolute/path/AuthKey_<KEY_ID>.p8" \
./release_testflight.sh --team-id "<APPLE_TEAM_ID>"
```

Sadece archive + IPA (upload olmadan):

```bash
cd app/ios
./release_testflight.sh --team-id "<APPLE_TEAM_ID>" --skip-upload
```

## 5) Kapanis Komutu (Ops)

Release ops item'larini id bazli guncelle:

```bash
python3 tools/release/set_release_ops_status.py \
  --id app_store_seo_app_name_localized \
  --status completed \
  --evidence-link "https://appstoreconnect.apple.com/..."
```

Toplu guncelleme (ornek: required maddeleri in_progress):

```bash
python3 tools/release/set_release_ops_status.py \
  --required-only \
  --status in_progress \
  --evidence-link "docs/RELEASE_PIPELINE_TR.md"
```
