# Video Plan

Bu repo icinde video tarafi icin storyboard ve lottie spec dosyalari uretildi:

1. `generated/assets/video/storyboards/onboarding_story.md`
2. `generated/assets/video/storyboards/quick_log_flow.md`
3. `generated/assets/video/storyboards/doctor_share_flow.md`
4. `generated/assets/motion/lottie_specs/breathing_loader.txt`
5. `generated/assets/motion/lottie_specs/sync_success.txt`

## Uygulama ici onerilen kullanimi

1. Onboarding son ekraninda 8-12 saniye loop feature reel
2. Doktor paylasim ekraninda mikro animasyon
3. Sync tamamlandi durumunda lottie animasyonu

## Not

Bu ortamda ffmpeg bulunmadigi icin MP4 render otomasyonu eklenmedi.
Mevcut storyboard/lottie spesifikasyonlariyla motion pipeline'da final video uretilir.
