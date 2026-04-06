# Ninni Lisans Playbook (TR)

Bu dokuman bilgilendirme amaclidir; resmi hukuki gorus degildir.
Yayina cikmadan once telif hukuku konusunda avukat onayi alinmalidir.

## 1) BabyTrack Icin Onerilen Yol

Onerilen ana yol:

1. Anonim / public-domain eser melodileri sec.
2. Tum kayitlari sifirdan kendimiz uret (yeni master kayit).
3. Her parca icin eser + master hak kanitini registry dosyasinda sakla.

Bu yol, maliyet/riski dengeli sekilde dusurur ve App Store review'da savunmasi en kolay modeldir.

## 2) Secenek Karsilastirmasi

1. Anonim/public-domain + yeni kayit (onerilen)
   - Artisi: Lisans maliyeti dusuk, kontrol yuksek.
   - Eksisi: Her parcada kaynak ve domain kaniti toplamak gerekir.
2. Mevcut ticari kayitlari lisanslamak
   - Artisi: Bilinen repertuvar.
   - Eksisi: Eser + icra + fonogram katmanlarinda daha karmasik sozlesme.
3. AI ile muzik uretmek (Gemini/Lyria)
   - Artisi: Hizli prototipleme.
   - Eksisi: Hukuki ve urunsel risk (benzer cikti ihtimali, model/servis degisikligi, watermark/safety sinirlari).

## 3) Neden Bu Kadar Kritik?

1. Apple, uygulamada kullandigin icerigin sana ait olmasini veya lisansli olmasini ister.
2. FSEK kapsaminda mali haklar (isleme, cogaltma, yayma, iletim) korunur.
3. Public-domain eser secsen bile mevcut bir kaydi kullanirsan, o kaydin ayrica hak sahibinden izin gerekir.

## 4) Operasyonel Akis

1. Repertuvari track bazinda siniflandir:
   - `public_domain`
   - `traditional/anonymous`
   - `licensed_commercial`
   - `ai_generated`
2. Her track icin en az su kanitlari topla:
   - Eser hak dayanak belgesi (public-domain notu veya lisans)
   - Master kayit hak belgesi (sozlesme/devir)
3. Registry guncelle:
   - `content/lullabies/lullaby_rights_registry_v1.json`
   - Toplu guncelleme komutu:

```bash
python3 tools/audio/set_rights_clearance.py \
  --country TR \
  --status in_review \
  --evidence-link "https://proof.example/legal-review"
```

4. Sadece `clearanceStatus = "cleared"` olan trackleri release'e al.
5. Strict kontrol:

```bash
python3 tools/audio/validate_rights_registry.py --require-cleared
```

## 5) Gemini/Lyria Kullanacaksak

1. Bunu prod ana repertuvari degil, fallback veya promosyon klipleri icin dusun.
2. Uretilen her parcayi benzersizlik ve marka-guven acisindan manuel QA'dan gecir.
3. Terms, watermark ve kullanim kosullari degisebilecegi icin release oncesi tekrar dogrula.

## 6) BabyTrack Icin Net Karar

Ilk production release icin:

1. Ana repertuvar: anonim/public-domain ezgiler + bize ait yeni master kayit.
2. AI muzik: yalnizca opsiyonel/fallback alanlarda, hukuk onayi sonrasi.
3. Lisans registry tamamlanmadan ninni modulu production acilmaz.
