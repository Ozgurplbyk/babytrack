# BabyTrack iOS Blueprint

Bu klasor SwiftUI tabanli iOS-first uygulama iskeletini icerir.

## Moduller

1. Onboarding
2. Today / Timeline / Quick Add / Health / Family tab yapisi
3. Paywall
4. Bu Surumde Neler Var (version upgrade sheet)
5. Ses Merkezi:
   - Beyaz gurultu
   - Kahverengi gurultu
   - Fon makinesi sesi
   - Ulkeye gore top 10 ninni oynatma

## Kaynaklar

- `Resources/Generated`: UI gorselleri
- `Resources/Audio/noise`: noise wav dosyalari
- `Resources/Audio/lullabies`: ulke bazli ninni wav dosyalari
- `Resources/Config/lullaby_catalog.json`
- `Resources/Config/changelog_latest.json`
- `Resources/Config/paywall_offers.json`

## Not

Ninni sesleri bu repoda lisans-riski olusturmamak icin uygulama ici placeholder enstrumantal olarak uretilmistir.
Ticari yayin oncesi repertuvar ve telif dogrulamasi yapilmalidir.

## Yerel Backend

Uygulama varsayilan olarak `http://127.0.0.1:8787` adresine baglanir.

Calistirmak icin:

```bash
./scripts/run_backend_api.sh
```

`uvicorn` yoksa script otomatik olarak stdlib fallback API ile calisir.

## Xcode'da Target Gorunmeme Sorunu

Eger Xcode'da sadece klasor agaci gorunuyor ve target/scheme yoksa, klasoru acmissindir.
Bu proje `xcodegen` ile uretilen `.xcodeproj` dosyasiyla acilmalidir.

1. XcodeGen kur:

```bash
brew install xcodegen
```

2. Projeyi uret:

```bash
cd app/ios
./generate_xcodeproj.sh
```

Tek komutta uret + ac (opsiyonel smoke build):

```bash
cd app/ios
./bootstrap_xcode.sh
# veya
./bootstrap_xcode.sh --build-smoke
```

3. Xcode'da dogru dosyayi ac:

```bash
open BabyTrack.xcodeproj
```

4. Build:
   - Scheme: `BabyTrack`
   - Destination: bir iPhone Simulator (orn. iPhone 16)
   - Run: `Cmd + R`

CLI build:

```bash
xcodebuild \
  -project BabyTrack.xcodeproj \
  -scheme BabyTrack \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## TestFlight Upload (CLI)

App Store signing + IPA export + TestFlight upload icin:

```bash
cd app/ios
ASC_API_KEY_ID="<APP_STORE_CONNECT_KEY_ID>" \
ASC_API_ISSUER_ID="<APP_STORE_CONNECT_ISSUER_ID>" \
ASC_P8_FILE_PATH="/absolute/path/AuthKey_<KEY_ID>.p8" \
./release_testflight.sh --team-id "<APPLE_TEAM_ID>"
```

Sadece archive + IPA almak istersen:

```bash
cd app/ios
./release_testflight.sh --team-id "<APPLE_TEAM_ID>" --skip-upload
```

Notlar:

1. Script varsayilan olarak `./generate_xcodeproj.sh` calistirir.
2. Cikti klasoru: `app/ios/build` (`.xcarchive` + `.ipa`).
3. Kendi export plist'in varsa `--export-options-plist` ile verebilirsin.

### API Token

Eger backend `BABYTRACK_API_TOKEN` ile calisiyorsa iOS tarafinda ayni token degeri gereklidir.

1. `app/ios/project.yml` icindeki `INFOPLIST_KEY_BABYTRACK_API_TOKEN` alanini doldur.
2. Ardindan proje dosyasini yeniden olustur:

```bash
cd app/ios
./generate_xcodeproj.sh
```

### Sync Device Binding

Backend `BABYTRACK_SYNC_REQUIRE_DEVICE_BINDING=1` ile calisiyorsa
`/v1/events/sync` isteklerinde su headerlar zorunludur:

1. `X-BabyTrack-Device-Id`
2. `X-BabyTrack-Nonce`

iOS istemci bu headerlari otomatik ekler (kalici device id + her istek icin yeni nonce).

### Subscription Product IDs

Paywall planlari App Store urunleriyle `appStoreProductId` alanindan eslesir:

1. `monthly` -> `com.babytrack.premium.monthly`
2. `annual` -> `com.babytrack.premium.annual`
3. `family_annual` -> `com.babytrack.premium.family.annual`

Config dosyasi:

`BabyTrack/Resources/Config/paywall_offers.json`
