# SeaTrack

Pencatat transaksi otomatis untuk Android. SeaTrack membaca notifikasi **SeaBank**, **DANA**, dan **GoPay**, mengenali nominal serta arah transaksi, lalu menyimpannya ke database SQLite di perangkat. Tanpa server, tanpa akun, tanpa data dummy.

## Fitur

- Pencatatan otomatis dari notifikasi: transfer masuk/keluar, QRIS, top up, bunga, cashback, refund.
- Notifikasi promo dan OTP diabaikan walau menyebut nominal.
- Penyimpanan lokal penuh. Data tidak pernah meninggalkan perangkat dan aplikasi tetap jalan tanpa internet.
- Dashboard: saldo bersih bulan ini atau semua waktu, grafik 7 hari, transaksi terbaru.
- Daftar transaksi dikelompokkan per hari dengan subtotal, pencarian, filter jenis dan sumber.
- Tambah manual, ubah, hapus (geser ke kiri), dan hapus semua data dari Pengaturan.
- Sapuan notifikasi aktif saat aplikasi dibuka, untuk menangkap transaksi yang terlewat saat proses aplikasi mati.
- Pengecualian optimasi baterai lewat MethodChannel kecil, tanpa plugin tambahan.
- Pembaruan otomatis mandiri lewat GitHub Releases: delta patch puluhan KB, verifikasi SHA-256, pasang sendiri di Android 12+.
- Tema terang dan gelap mengikuti sistem.

## Dependensi

`sqflite`, `notification_listener_service`, `provider`, `intl`. Tidak ada yang lain.

## Setup

Tidak ada konfigurasi. Tabel dibuat otomatis saat aplikasi pertama kali dibuka.

```bash
flutter pub get
flutter run
```

Di aplikasi, berikan **Akses notifikasi** dan kecualikan dari **Optimasi baterai**.

Build rilis:

```bash
flutter build apk --release --split-per-abi
```

Di Windows, bila Gradle gagal dengan `Unable to establish loopback connection`, jalankan `build.cmd`. Skrip itu mengarahkan folder temp Java ke path pendek (`C:\Temp\jtmp`), karena JDK 16+ membuat pipe internal lewat Unix domain socket dan gagal bila TEMP memakai nama pendek 8.3 seperti `C:\Users\CREATO~1\...`.

## Cara kerja

```
Notifikasi bank ──► NotificationListenerService (Android)
                          │
                          ▼
             ListenerController (stream + sapuan notifikasi aktif)
                          │  dedup: cek created_at di database
                          ▼
              NotificationParser.parse()  ──► null bila promo/OTP/tanpa nominal
                          │
                          ▼
           TransactionProvider.add() ──► SQLite `transactions`
```

Sumber transaksi (SeaBank/DANA/GoPay) disimpan sebagai prefix judul, contoh `SeaBank · Dari BUDI`, sehingga tabel tetap lima kolom.

## Database

File `seatrack.db` di penyimpanan internal aplikasi, dibuat otomatis:

```sql
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  amount REAL NOT NULL CHECK (amount > 0),
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  created_at TEXT NOT NULL
);
```

Waktu disimpan sebagai teks ISO-8601 dalam UTC, lalu ditampilkan dalam waktu lokal. Menghapus aplikasi akan menghapus database.

## Pembaruan otomatis

SeaTrack tidak lewat Play Store, jadi pembaruan diurus sendiri. Modulnya diadaptasi dari `core/update` milik SUPER-APPS, termasuk delta patch-nya. Bedanya, tidak ada server: GitHub yang menjadi backend-nya.

Dorong ke `main`, dan [alur rilis](.github/workflows/release.yml) mengerjakan sisanya.

```
git push origin main
        │
        ▼
GitHub Actions: analyze, test, build APK bertanda tangan
        │  versionCode = jumlah commit di main
        ▼
Bandingkan dengan 3 APK rilis sebelumnya ──► buat patch delta
        │
        ▼
Terbitkan GitHub Release: APK + patch + update.json
        │
        ▼  https://github.com/<owner>/<repo>/releases/latest/download/update.json
Perangkat menariknya saat aplikasi dibuka, paling sering sekali tiap 4 jam
        │
        ▼
Ada patch untuk versi terpasang?  ──ya──► unduh patch (puluhan KB)
        │                                        │
        tidak                                    ▼
        │                          Susun ulang APK di perangkat
        ▼                                        │
Unduh APK penuh ◄──── patch gagal ───────────────┘
        │
        ▼
Verifikasi SHA-256, pasang diam-diam (Android 12+), buka kembali sendiri
```

Patch dibuat oleh [tools/DeltaGen.java](tools/DeltaGen.java) dan dipakai `ApkDeltaApplier.kt`. Keduanya memakai File-by-File v1 dari `com.eidu:archive-patcher` dengan deflate mentah, jadi formatnya harus tetap sepasang. Pada uji dua build berurutan, patch berukuran 51 KB untuk APK 52 MB.

### Kunci penandatanganan

Pembaruan hanya bisa terpasang bila APK baru ditandatangani kunci yang sama dengan yang sudah ada di perangkat. Kunci debug dibuat ulang di tiap mesin, jadi rilis wajib memakai keystore tetap.

Keystore proyek ini sudah dibuat dan terpasang:

| | |
| --- | --- |
| Berkas | `C:\Users\<pengguna>\.seatrack\seatrack.jks`, di luar repositori |
| Alias | `seatrack` |
| Sidik jari SHA-256 | `f73de3f750c7cc30704c9e4257b0b70a497c3c3302fe0cc81befae01722299a6` |

Empat secret yang dipakai CI sudah terisi: `SEATRACK_KEYSTORE_BASE64`, `SEATRACK_KEYSTORE_PASSWORD`, `SEATRACK_KEY_ALIAS`, `SEATRACK_KEY_PASSWORD`. Build lokal memakai `android/key.properties`, yang diabaikan git.

**Cadangkan berkas keystore itu.** Kalau hilang, tidak ada cara memperbarui aplikasi yang sudah terpasang. Satu-satunya jalan adalah menyuruh setiap pengguna mencopot lalu memasang ulang dengan kunci baru.

Untuk membuat ulang dari nol di proyek lain:

```bash
keytool -genkeypair -keystore seatrack.jks -alias seatrack -keyalg RSA -keysize 4096 \
  -validity 10000 -dname "CN=SeaTrack, OU=Mobile, O=<owner>, C=ID"
gh secret set SEATRACK_KEYSTORE_BASE64 < <(base64 -w0 seatrack.jks)
```

### Catatan penting

- **Sekali saja perlu pasang ulang.** APK yang dibangun sebelum keystore ini ada ditandatangani kunci debug, jadi perangkat akan menolaknya sebagai pembaruan. Copot lalu pasang ulang dari rilis GitHub pertama.
- **APK universal, bukan split per ABI.** Delta patch dihitung terhadap satu berkas dasar, jadi semua perangkat harus memakai APK yang sama. Unduhan pertama memang 52 MB, tetapi pembaruan berikutnya tinggal puluhan KB.
- **versionCode diambil dari jumlah commit** di `main`, jadi tidak perlu menaikkannya manual. `version:` di pubspec tetap dipakai sebagai nama versi yang tampil.
- Patch yang gagal, misalnya karena APK terpasang tidak persis sama dengan yang dipakai saat patch dibuat, otomatis jatuh kembali ke APK penuh.
- Pemasangan diam-diam butuh Android 12+. Di bawah itu sistem menampilkan dialog konfirmasi biasa.
- Sekali saja pengguna diminta mengizinkan "pasang aplikasi tidak dikenal". Izin "tampil di atas aplikasi lain" opsional, hanya agar aplikasi bisa membuka dirinya sendiri setelah pembaruan.
- Untuk mematikan fitur ini, kosongkan `_fallback` di [lib/core/update_config.dart](lib/core/update_config.dart). Tidak akan ada permintaan jaringan sama sekali.

## Struktur

```
lib/
  core/         tema, formatter, daftar sumber, URL manifest update
  models/       TransactionModel
  services/     database SQLite, parser notifikasi, baterai, jembatan update
  repositories/ CRUD SQLite
  providers/    TransactionProvider, ListenerController, ActivityLog, UpdateController
  screens/      dashboard, transaksi, pengaturan, log, form
  widgets/      komponen UI kecil

android/app/src/main/kotlin/com/rendydev404/seatrack/
  MainActivity.kt        MethodChannel baterai + pemasangan plugin update
  update/                unduh, tambal, verifikasi, pasang, buka kembali

tools/DeltaGen.java      pembuat patch, dipakai GitHub Actions
.github/workflows/       alur rilis otomatis
```

## Tes

```bash
flutter test
```

Parser diuji terhadap contoh notifikasi ketiga aplikasi, termasuk format nominal `50.000`, `50.000,00`, dan `50,000.00`.

## Catatan

- Event notifikasi hanya sampai ke Dart saat proses aplikasi hidup. Karena itu aplikasi menyapu notifikasi yang masih ada di panel setiap kali dibuka.
- Karena data hanya ada di perangkat, tidak ada sinkronisasi antar-HP. Cadangkan sendiri bila perlu.
