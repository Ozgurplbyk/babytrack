# App Icon Name Localization Policy (Auto)

- generatedAtUtc: `2026-02-28T12:18:41+00:00`
- sourceRegistry: `config/localization/app_display_name_registry_v1.json`
- localizationRoot: `app/ios/BabyTrack/Resources/Localization`

## Kural

1. Home Screen icon altindaki isim `CFBundleDisplayName` alanindan gelir.
2. Her locale icin isim `app_display_name_registry_v1.json` uzerinden yonetilir.
3. Yeni dil/bolge eklendiginde bu script yeniden calistirilir; hem `InfoPlist.strings` hem bu rapor guncellenir.
4. `status=missing_registry` ise locale var ama ad registry'de tanimli degildir; yayin oncesi tamamlanmalidir.

## Locale Tablosu

| Locale | Region | Language | Icon Name | Chars | Status |
|---|---|---|---|---:|---|
| `ar` | MENA | العربية | `متابعة الطفل` | 12 | configured |
| `de` | DE | Deutsch | `Baby Tracker` | 12 | configured |
| `en` | US/GB | English | `Baby Tracker` | 12 | configured |
| `es` | ES | Español | `Seguimiento Bebé` | 16 | configured |
| `fr` | FR | Français | `Suivi Bébé` | 10 | configured |
| `it` | IT | Italiano | `Traccia Bebè` | 12 | configured |
| `pt-BR` | BR | Português (Brasil) | `Rastreador Bebê` | 15 | configured |
| `tr` | TR | Türkçe | `Bebek İzleme` | 12 | configured |

## Calistirma

```bash
python3 tools/localization/sync_app_display_names.py \
  --registry config/localization/app_display_name_registry_v1.json \
  --localization-root app/ios/BabyTrack/Resources/Localization \
  --doc-out docs/APP_NAME_LOCALIZATION_POLICY_AUTO_TR.md
```

