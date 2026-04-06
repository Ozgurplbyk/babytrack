# App Store Subscription Checklist (TR)

## 1) Product ID Eslesmesi

Asagidaki planlar App Store Connect'te birebir ayni product id ile acilmalidir:

1. `monthly` -> `com.babytrack.premium.monthly`
2. `annual` -> `com.babytrack.premium.annual`
3. `family_annual` -> `com.babytrack.premium.family.annual`

Kaynak:

1. `config/paywall/paywall_offers.json`
2. `app/ios/BabyTrack/Resources/Config/paywall_offers.json`

## 2) App Store Connect Adimlari

1. Subscription Group olustur: `BabyTrack Premium`.
2. Uc urunu ac (monthly/annual/family annual).
3. Free trial gunleri ve fiyat katmanlarini paywall dosyasi ile hizala.
4. Localized display name/description alanlarini tamamla.
5. Availability ve tax kategori ayarlarini kontrol et.

## 3) Teknik Dogrulama

1. Yerelde mapping kontrolu:

```bash
python3 tools/paywall/validate_paywall_products.py
```

2. iOS'ta StoreKit urunleri yukleniyor mu kontrol et.
3. Her plan icin satin alma ve restore smoke testi yap.
4. Localized metadata dogrulamasi:

```bash
python3 tools/release/validate_app_store_metadata.py
```

5. App Store giris sheet'i olustur:

```bash
python3 tools/release/generate_app_store_localization_sheet.py
```

## 4) Release Gate

`validate_paywall_products.py` basarisizsa release block edilir.

## 5) Operasyon Takibi

App Store adimlarini release operasyon kaydina kanit linkiyle isle:

1. `config/release/release_ops_registry_v1.json`
2. `docs/RELEASE_OPS_ACTION_BOARD_TR.md`
3. Bolge/dil bazli isimlendirme: `docs/APP_NAME_LOCALIZATION_SEO_TR.md`
4. App Store locale giris tablosu: `docs/APP_STORE_LOCALIZATION_UPLOAD_SHEET_TR.md`
