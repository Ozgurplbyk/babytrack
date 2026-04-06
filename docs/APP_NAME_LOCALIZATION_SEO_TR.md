# App Name Localization + SEO Rehberi (TR)

## Amac

Her yeni bolge acilisinda, o bolge/dile uygun App Store metadata'si ile daha iyi arama gorunurlugu saglamak.

## Kural Seti

1. Marka koku sabit: `BabyTrack` (veya lokal pazarda kabul edilmis marka varyanti).
2. App Name: kisa, net, kategori anahtar kelimesi icersin.
3. Subtitle: birincil kullanim senaryolarini anlatsin (uyku, emzirme, bez, ilac vb.).
4. Keyword alaninda tekrar yok; App Name + Subtitle'da gecen kelimeleri tekrar etme.
5. Turkce metadata transliterasyonsuz olmali (`c/g/i/o/s/u` yerine `ç/ğ/ı/ö/ş/ü`).
6. Yayina cikmadan once karakter limitlerini App Store Connect'te dogrula.

## Kaynak Dosya + Dogrulama

1. Metadata kaynagi: `config/app_store/app_store_metadata_localized_v1.json`
2. Validator:

```bash
python3 tools/release/validate_app_store_metadata.py
```

## Icon Alti Uygulama Adi (Otomatik Yonetim)

1. Registry kaynagi: `config/localization/app_display_name_registry_v1.json`
2. Senkron script:

```bash
python3 tools/localization/sync_app_display_names.py \
  --registry config/localization/app_display_name_registry_v1.json \
  --localization-root app/ios/BabyTrack/Resources/Localization \
  --doc-out docs/APP_NAME_LOCALIZATION_POLICY_AUTO_TR.md
```

3. Otomatik rapor: `docs/APP_NAME_LOCALIZATION_POLICY_AUTO_TR.md`

## Mevcut Diller Icin Oneri Seti

| Locale | Hedef Pazar | Onerilen App Name | Onerilen Subtitle | Keyword Set (ornek) |
|---|---|---|---|---|
| `en-US` | US | `BabyTrack: Baby Tracker` | `Sleep, Feeding, Diaper Log` | `newborn routine,breastfeeding timer,milestone journal,growth log,family tracker` |
| `en-GB` | GB | `BabyTrack: Baby Tracker` | `Sleep, Feeding, Nappy Log` | `newborn routine,breastfeeding timer,milestone journal,growth log,family tracker` |
| `tr-TR` | Turkiye | `BabyTrack: Bebek Takip` | `Uyku, Emzirme, Bez Takibi` | `yenidoğan rutin,gelişim günlüğü,aşı hatırlatıcı,biberon kaydı,aile paylaşımı` |
| `de-DE` | Almanya | `BabyTrack: Baby Tracker` | `Schlaf, Stillen, Windel` | `baby tagebuch,neugeborenen routine,fieber protokoll,milchmenge,familien kalender` |
| `es-ES` | Ispanya | `BabyTrack: Seguimiento Bebé` | `Sueño, Lactancia, Pañal` | `rutina recién nacido,sueño infantil,diario familiar,recordatorio vacuna,biberón` |
| `fr-FR` | Fransa | `BabyTrack: Suivi Bébé` | `Sommeil, Allaitement, Couches` | `routine nouveau-né,sommeil enfant,journal famille,rappel vaccin,biberon` |
| `it-IT` | Italya | `BabyTrack: Diario Bebè` | `Sonno, Pappa e Pannolino` | `routine neonato,allattamento timer,sonno bimbo,promemoria vaccini,diario famiglia` |
| `pt-BR` | Brezilya | `BabyTrack: Diário do Bebê` | `Sono, Amamentação, Fralda` | `rotina recém nascido,sono infantil,lembrete vacina,diário familiar,mamadeira` |
| `ar-SA` | Arapca pazarlar | `BabyTrack: تتبع الطفل` | `النوم والرضاعة والحفاض` | `روتين المولود,نوم الرضيع,تذكير اللقاح,مذكرات الطفل,متابعة النمو` |

## Yeni Bolge Ekleme Akisi

1. Yeni locale sec (`xx-YY`).
2. App Name + Subtitle + Keyword setini bu dosyaya ekle.
   - JSON kaynagi: `config/app_store/app_store_metadata_localized_v1.json`
3. App Store Connect'te ilgili locale metadata'sini doldur.
4. Kanit linkini `config/release/release_ops_registry_v1.json` icine isle.
5. `python3 tools/release/generate_release_ops_board.py` ile operasyon panosunu guncelle.
