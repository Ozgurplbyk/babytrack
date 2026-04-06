# Sync Data Policy (TR)

Bu dokuman bilgilendirme amaclidir; resmi hukuki/uyumluluk gorusu degildir.

## 1) Kapsam

1. `backend/api/data/sync_events.db` icindeki event sync verileri.
2. Replay-guard tablosu (request digest kayitlari).

## 2) Backup Onerisi

1. Gunluk en az 1 snapshot.
2. Yogun trafik saatlerinde 6 saatte bir snapshot (opsiyonel).
3. Komut:

```bash
./scripts/backup_sync_db.sh
```

## 3) Retention Onerisi

1. Son 30 gun: saatlik/gunluk snapshotlar.
2. Son 12 ay: haftalik snapshotlar.
3. 12 ay sonrasi: aylik arsiv.
4. Uygulama retention sweep:
   - `BABYTRACK_SYNC_RETENTION_DAYS` (varsayilan: 365)
   - `BABYTRACK_SYNC_RETENTION_SWEEP_SEC` (varsayilan: 3600)
5. Manuel retention komutu:

```bash
./scripts/prune_sync_db.sh
```

## 4) Restore Testi

1. Aylik en az 1 kez yedekten geri donus smoke testi yap.
2. Basarili restore kanitini (tarih, sorumlu, sonuc) operasyon notlarinda sakla.

## 5) Guvenlik

1. Backup dosyalarini sifreli depoda sakla.
2. Erişimleri en az yetki prensibiyle sinirla.
