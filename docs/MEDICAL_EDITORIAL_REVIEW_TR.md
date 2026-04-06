# Medical Editorial Review (TR)

## 1) Kaynak Dosya

`content/medical/medical_content_registry_v1.json`

Bu dosya moduller bazinda klinik + hukuk onay durumunu takip eder.

## 2) Status Alanlari

1. `pending`
2. `approved`
3. `rework_required`

## 3) Onay Kriterleri

1. Klinik ifade dogrulugu (yaniltici tanisal dil yok).
2. Acil durum yonlendirmesinde netlik ve risk azaltma.
3. Lokal regülasyon ve disclaimer uyumu.
4. Kaynak referanslarinin registry'de belirtilmesi.

## 4) Release Gate

1. Registry schema validation:

```bash
python3 tools/content/validate_medical_registry.py
```

Strict gate:

```bash
python3 tools/content/validate_medical_registry.py --require-approved
```

Toplu status guncelleme:

```bash
python3 tools/content/set_medical_review_status.py \
  --module triage \
  --editorial-status approved \
  --legal-status pending \
  --set-reviewed-now \
  --evidence-source "https://proof.example/clinical-review"
```

2. Production release oncesi hedef:
   - Tum modullerde `editorialStatus = approved`
   - Tum modullerde `legalStatus = approved`
