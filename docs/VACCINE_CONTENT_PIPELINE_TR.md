# Vaccine Icerik Pipeline (TR)

## Amaç

Ulke bazli asi takvimi icerigini:

1. Resmi otorite kaynagina bagli,
2. Surumlenebilir,
3. Release gate ile dogrulanabilir

sekilde yonetmek.

## Kaynaklar

1. Medikal genel onay registry:
   - `content/medical/medical_content_registry_v1.json`
2. Ulke-kaynak eslesme registry:
   - `content/medical/vaccine_country_source_registry_v1.json`
3. Pipeline paket ciktilari:
   - `backend/vaccine_pipeline/output/{COUNTRY}_{VERSION}.json`

## Dogrulama

```bash
python3 tools/content/validate_vaccine_source_registry.py \
  --registry content/medical/vaccine_country_source_registry_v1.json \
  --output-dir backend/vaccine_pipeline/output
```

Bu dogrulama:

1. Desteklenen ulkelerin tam kapsamini,
2. `pipeline_package` ulkeleri icin guncel paket varligini,
3. Resmi kaynak URL ve temel alan tutarliligini

kontrol eder.

## Uygulama Davranisi

1. iOS `Aşı Takvimi` ekrani once backend endpointinden son paketi ceker:
   - `/v1/vaccines/packages/{country}/latest`
2. Paket varsa `authority + version` etiketiyle listeler.
3. Paket yoksa local seed data fallback'e, o da yoksa manuel kayda duser.
