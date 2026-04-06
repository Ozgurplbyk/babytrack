# Release Ops Action Board (TR)

- generatedAtUtc: `2026-02-27T21:40:58.888473+00:00`
- totalItems: `11`
- pendingRequiredItems: `0`

## app_store

- [x] `app_store_subscription_products_active` (required/completed) - App Store subscription urunleri active | owner=App Store Ops Team | target=2026-03-15 | evidence=docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md, docs/RELEASE_PIPELINE_TR.md
- [x] `app_store_pricing_trial_checked` (required/completed) - Pricing ve trial ayarlari paywall ile uyumlu | owner=App Store Ops Team | target=2026-03-15 | evidence=docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md, docs/RELEASE_PIPELINE_TR.md
- [x] `app_store_localizations_completed` (required/completed) - App Store urun metadata lokalizasyonlari tamamlandi | owner=App Store Ops Team | target=2026-03-15 | evidence=docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md, docs/RELEASE_PIPELINE_TR.md
- [x] `app_store_seo_app_name_localized` (required/completed) - Bolge/dil bazli SEO uyumlu app name + subtitle girildi | owner=App Store Ops Team | target=2026-03-15 | evidence=docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md, docs/RELEASE_PIPELINE_TR.md

## backend_release

- [x] `backend_prod_deploy_completed` (required/completed) - Backend production deploy tamamlandi | owner=Backend Platform Team | target=2026-03-20 | evidence=docs/RELEASE_PIPELINE_TR.md, docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md
- [x] `backend_post_deploy_health_check` (required/completed) - Post-deploy health check gecildi | owner=Backend Platform Team | target=2026-03-20 | evidence=docs/RELEASE_PIPELINE_TR.md, docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md

## ios_release

- [x] `testflight_upload_completed` (required/completed) - TestFlight build upload tamamlandi | owner=iOS Release Team | target=2026-03-18 | evidence=docs/RELEASE_PIPELINE_TR.md, docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md
- [x] `testflight_smoke_completed` (required/completed) - TestFlight smoke test tamamlandi | owner=iOS Release Team | target=2026-03-18 | evidence=docs/RELEASE_PIPELINE_TR.md, docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md

## operations

- [x] `rollback_plan_verified` (required/completed) - Rollback plani test edilip onaylandi | owner=SRE Operations Team | target=2026-03-22 | evidence=docs/PHASE_3_RELEASE_HARDENING_TR.md, docs/RELEASE_PIPELINE_TR.md, docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md
- [x] `incident_runbook_ready` (optional/completed) - Incident runbook linkleri guncel | owner=SRE Operations Team | target=2026-03-22 | evidence=docs/PHASE_3_RELEASE_HARDENING_TR.md, docs/RELEASE_PIPELINE_TR.md, docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md
- [x] `monitoring_alerts_ready` (optional/completed) - Monitoring dashboard ve alert threshold'lar hazir | owner=SRE Operations Team | target=2026-03-22 | evidence=docs/PHASE_3_RELEASE_HARDENING_TR.md, docs/RELEASE_PIPELINE_TR.md, docs/APP_STORE_SUBSCRIPTIONS_CHECKLIST_TR.md
