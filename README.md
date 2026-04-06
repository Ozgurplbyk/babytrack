# BabyTrack Product + Content + iOS Blueprint

This workspace now contains:

1. End-to-end product plan for a 0-18 child health + memory app.
2. Information architecture and menu design for fast daily logging.
3. Premium conversion strategy.
4. A full visual content manifest (all modules, not only menu screens).
5. A Gemini-powered content generation script for consistent assets.
6. iOS SwiftUI blueprint (onboarding, paywall, what's new, tab shell, audio hub).
7. Audio generation pipeline (white/brown/hair dryer noise + country-based lullaby library).
8. Vaccine schedule auto-update backend pipeline skeleton.

## Quick Start

1. Add your Gemini API key:

```bash
export GEMINI_API_KEY="YOUR_KEY"
```

Optional (recommended for auth-enabled API runs):

```bash
export BABYTRACK_API_TOKEN="YOUR_TOKEN"
```

Optional (token rotation window, comma-separated):

```bash
export BABYTRACK_API_TOKENS="NEW_TOKEN,OLD_TOKEN"
```

Optional (for custom sync DB location):

```bash
export BABYTRACK_SYNC_DB="/abs/path/to/sync_events.db"
```

Optional (hardening controls):

```bash
export BABYTRACK_RATE_LIMIT_PER_MIN="120"
export BABYTRACK_SYNC_REPLAY_WINDOW_SEC="300"
export BABYTRACK_SYNC_REQUIRE_DEVICE_BINDING="1"
export BABYTRACK_SYNC_RETENTION_DAYS="365"
export BABYTRACK_SYNC_RETENTION_SWEEP_SEC="3600"
```

2. Generate assets from manifest:

```bash
python3 tools/gemini/generate_assets.py \
  --manifest assets/manifest/asset_manifest_v1.json \
  --style tools/gemini/style_system.json \
  --out generated/assets
```

3. Generate storyboard specs for videos/lottie:

```bash
python3 tools/gemini/generate_assets.py \
  --manifest assets/manifest/asset_manifest_v1.json \
  --style tools/gemini/style_system.json \
  --out generated/assets \
  --kinds storyboard lottie_spec
```

4. Generate localizations:

```bash
python3 tools/localization/translate_localization_with_gemini.py \
  --base config/localization/base_strings_en.json \
  --out app/ios/BabyTrack/Resources/Localization \
  --locales en tr de es fr it pt-BR ar
```

To generate both `Localizable.strings` and `InfoPlist.strings` (App/Widget/Watch), use:

```bash
./scripts/run_localization.sh
```

To enforce locale-specific app icon names (`CFBundleDisplayName`) from registry and regenerate policy markdown:

```bash
python3 tools/localization/sync_app_display_names.py \
  --registry config/localization/app_display_name_registry_v1.json \
  --localization-root app/ios/BabyTrack/Resources/Localization \
  --doc-out docs/APP_NAME_LOCALIZATION_POLICY_AUTO_TR.md
```

5. Generate audio library:

```bash
python3 tools/audio/generate_audio_library.py \
  --catalog content/lullabies/lullaby_catalog.json \
  --out app/ios/BabyTrack/Resources/Audio
```

6. Validate lullaby rights registry (release gate helper):

```bash
python3 tools/audio/validate_rights_registry.py
```

Toplu clearance status guncelleme:

```bash
python3 tools/audio/set_rights_clearance.py \
  --country TR \
  --status in_review \
  --evidence-link "https://your-proof-link.example"
```

7. Validate paywall App Store product mapping:

```bash
python3 tools/paywall/validate_paywall_products.py
```

8. Validate medical content registry:

```bash
python3 tools/content/validate_medical_registry.py
```

Toplu editorial/legal status guncelleme:

```bash
python3 tools/content/set_medical_review_status.py \
  --all \
  --editorial-status approved \
  --legal-status pending \
  --set-reviewed-now
```

9. Validate localized App Store metadata:

```bash
python3 tools/release/validate_app_store_metadata.py
```

10. Generate App Store localization upload sheet:

```bash
python3 tools/release/generate_app_store_localization_sheet.py
```

11. Generate closure playbook (pending maddeler icin komut sablonlari):

```bash
python3 tools/release/generate_closure_playbook.py
```

12. Generate release readiness report:

```bash
python3 tools/release/release_readiness_report.py
```

13. Validate release ops registry:

```bash
python3 tools/release/validate_release_ops_registry.py
```

14. Generate compliance action board:

```bash
python3 tools/compliance/generate_action_board.py
```

15. Generate release ops action board:

```bash
python3 tools/release/generate_release_ops_board.py
```

16. Apply bulk owner/date/evidence template to rights/medical registries:

```bash
python3 tools/compliance/apply_registry_template.py \
  --replace-tbd-owner \
  --drop-placeholder-evidence
```

17. Apply bulk owner/date/evidence template to release ops registry:

```bash
python3 tools/release/apply_release_ops_template.py \
  --replace-tbd-owner \
  --drop-placeholder-evidence
```

18. Build vaccine schedule packages:

```bash
python3 backend/vaccine_pipeline/run_update_cycle.py
```

19. Run backend API:

```bash
./scripts/run_backend_api.sh
```

If `BABYTRACK_API_TOKEN` is set, all `/v1/*` endpoints require:

```http
Authorization: Bearer YOUR_TOKEN
```

`/v1/events/sync` records are persisted to SQLite (`backend/api/data/sync_events.db` by default).
Use `/v1/events/stats` for basic storage health checks.
Same sync payload replay within `BABYTRACK_SYNC_REPLAY_WINDOW_SEC` returns `409`.
If `BABYTRACK_SYNC_REQUIRE_DEVICE_BINDING=1`, sync requests must include both
`X-BabyTrack-Device-Id` and `X-BabyTrack-Nonce` headers (iOS app sends these automatically).

20. Backup sync database snapshot:

```bash
./scripts/backup_sync_db.sh
```

21. Apply sync database retention policy:

```bash
./scripts/prune_sync_db.sh
```

22. Run complete sequence:

```bash
export GEMINI_API_KEY="YOUR_KEY"
./scripts/run_all_phases.sh
```

23. Bootstrap iOS project for Xcode (fix target/scheme visibility):

```bash
cd app/ios
./bootstrap_xcode.sh --build-smoke
```

## Files

- `docs/MASTER_PRODUCT_PLAN_TR.md`
- `docs/IA_MENU_AND_DATA_FLOW_TR.md`
- `docs/PREMIUM_CONVERSION_PLAYBOOK_TR.md`
- `docs/CONTENT_PRODUCTION_PIPELINE_TR.md`
- `docs/IMPLEMENTATION_STATUS_TR.md`
- `docs/LULLABY_LICENSING_PLAYBOOK_TR.md`
- `docs/SYNC_DATA_POLICY_TR.md`
- `docs/REMAINING_ROADMAP_TR.md`
- `docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md`
- `docs/APP_NAME_LOCALIZATION_SEO_TR.md`
- `docs/APP_STORE_LOCALIZATION_UPLOAD_SHEET_TR.md`
- `docs/CLOSURE_PLAYBOOK_TR.md`
- `docs/RELEASE_PIPELINE_TR.md`
- `docs/MEDICAL_EDITORIAL_REVIEW_TR.md`
- `docs/RELEASE_READINESS_REPORT.md`
- `docs/COMPLIANCE_ACTION_BOARD_TR.md`
- `docs/RELEASE_OPS_ACTION_BOARD_TR.md`
- `docs/ACCOUNT_STRATEGY_TR.md`
- `assets/manifest/asset_manifest_v1.json`
- `tools/gemini/style_system.json`
- `tools/gemini/generate_assets.py`
- `tools/localization/translate_localization_with_gemini.py`
- `tools/audio/generate_audio_library.py`
- `tools/audio/validate_rights_registry.py`
- `tools/audio/set_rights_clearance.py`
- `tools/content/validate_medical_registry.py`
- `tools/content/set_medical_review_status.py`
- `tools/compliance/generate_action_board.py`
- `tools/compliance/apply_registry_template.py`
- `tools/release/release_readiness_report.py`
- `tools/release/validate_release_ops_registry.py`
- `tools/release/validate_app_store_metadata.py`
- `tools/release/generate_app_store_localization_sheet.py`
- `tools/release/generate_closure_playbook.py`
- `tools/release/generate_release_ops_board.py`
- `tools/release/apply_release_ops_template.py`
- `tools/release/set_release_ops_status.py`
- `tools/paywall/validate_paywall_products.py`
- `content/lullabies/lullaby_catalog.json`
- `content/lullabies/lullaby_rights_registry_v1.json`
- `content/medical/medical_content_registry_v1.json`
- `config/release/release_ops_registry_v1.json`
- `config/app_store/app_store_metadata_localized_v1.json`
- `app/ios/BabyTrack/...`
- `app/ios/bootstrap_xcode.sh`
- `backend/vaccine_pipeline/...`
- `backend/api/event_sync_store.py`
- `backend/api/security_controls.py`
- `backend/api/sync_db_backup.py`
- `backend/api/sync_db_retention.py`
- `scripts/backup_sync_db.sh`
- `scripts/prune_sync_db.sh`
- `.github/workflows/ci.yml`
- `.github/workflows/release_candidate.yml`
