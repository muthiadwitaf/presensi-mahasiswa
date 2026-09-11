# Presensi Liveness — Sistem Presensi Mahasiswa

Purwarupa aplikasi mobile presensi mahasiswa anti-titip-absen: login NIM +
liveness detection wajah (MobileNetV2, real vs spoof) + **pencocokan
identitas wajah (face recognition, MobileFaceNet)** via TensorFlow Lite +
pencatatan lokasi live saat Clock In/Out. Dibangun untuk skripsi *"Sistem
Presensi Mahasiswa Menggunakan Metode Deep Learning MobileNet untuk
Deteksi Liveness Anti-Titip Absen dengan Geofencing di Universitas Saintek
Muhammadiyah Jakarta"*.

> **PENTING — DUA perubahan metodologi belum tercermin di proposal
> tertulis, perlu direvisi & didiskusikan ke dosen pembimbing (Bapak
> Fitrah Juliansyah) sebelum diajukan lebih lanjut:**
>
> 1. **Face recognition ditambahkan (Opsi A).** Proposal yang ada
>    (`Proposal_Skripsi_...docx`) eksplisit menulis di Batasan Masalah
>    bahwa penelitian ini **"belum mencakup pengembangan model pengenalan
>    wajah (face recognition)"**, dan di Saran memposisikannya sebagai PR
>    peneliti selanjutnya. Kode SEKARANG SUDAH menambahkan face recognition.
> 2. **Validasi geofencing DIHAPUS.** Judul skripsi & KF-04 proposal
>    menyebut "geofencing" sebagai validasi radius lokasi ruang kelas. Atas
>    keputusan Anda, app ini TIDAK LAGI memvalidasi radius — lokasi live
>    hanya direkam sebagai log saat Clock In/Out (kolom lokasi di
>    `attendance_verifications`), bukan syarat lolos/gagal presensi.
>    Ini kemungkinan perlu direvisi paling hati-hati karena "Geofencing"
>    ada di JUDUL skripsi Anda — pertimbangkan apakah judul juga perlu
>    disesuaikan atau geofencing tetap disebut sebagai "pencatatan lokasi"
>    bukan "validasi radius". Diskusikan ini ke pembimbing.
>
> Proposal ini juga masih punya beberapa placeholder Bab III (profil
> kampus) yang belum dilengkapi dari sesi sebelumnya.

## Status saat ini

- Seluruh kode app (Flutter) sudah lengkap: semua menu (Beranda, Jadwal,
  Rekap, Wajah Terdaftar, Izin/Sakit, Kelola Kelas untuk dosen, Notifikasi)
  terhubung ke Supabase (PostgreSQL + Auth + Storage + Edge Functions),
  `flutter analyze` bersih.
- **Firebase sudah sepenuhnya dihapus** dari project ini (auth, Firestore,
  dependency, konfigurasi Android) - backend sekarang murni Supabase, lihat
  skema di `supabase/migrations/`.
- Model `assets/models/model.tflite` (liveness, MobileNetV2) SUDAH ada —
  **wajib dikalibrasi** sebelum dipakai untuk pengujian/sidang, lihat bagian
  "Model Liveness" di bawah.
- Model `assets/models/mobilefacenet.tflite` (pencocokan identitas wajah)
  SUDAH ada — lihat bagian "Model Face Recognition" di bawah untuk detail &
  catatan kalibrasi threshold-nya.

## 1. Setup Supabase (WAJIB sebelum app bisa dipakai penuh)

1. Buat project di [supabase.com](https://supabase.com) (atau jalankan
   Supabase lokal lewat Supabase CLI: `supabase start`).
2. Terapkan skema database: `supabase db push` (menjalankan seluruh file di
   `supabase/migrations/` secara berurutan), lalu (opsional) `supabase db
   seed` untuk data contoh (`supabase/seed.sql`).
3. Deploy Edge Functions yang dipakai app: `supabase functions deploy` untuk
   tiap fungsi di `supabase/functions/` (`activate-account`,
   `admin-provision-user`, `attendance-challenge`, `enroll-face`,
   `submit-attendance`, `submit-checkout`).
4. Di **Authentication → Providers → Email**, matikan **"Confirm email"** -
   app memakai email sintetis (`<NIM>@smartattendance.app`, lihat
   `lib/core/services/supabase_auth_service.dart`) yang tidak pernah bisa
   menerima email konfirmasi sungguhan.
5. Isi `env/dev.json` dengan `SUPABASE_URL` & `SUPABASE_ANON_KEY` project
   Anda, lalu jalankan app dengan:

   ```bash
   flutter run --dart-define-from-file=env/dev.json
   ```

   (Run configuration `main.dart` di Android Studio/.idea sudah diset untuk
   otomatis menyertakan argumen ini.)

Foto wajah terdaftar disimpan di bucket Storage privat `face-photos` (lewat
Edge Function `enroll-face`, embedding-nya di tabel `face_profiles` yang
tidak bisa dibaca langsung oleh client), dan lampiran bukti izin/sakit di
bucket `leave-attachments`. Tidak ada lagi penyimpanan Base64 di dokumen
database seperti versi Firestore dulu.

### Data awal

Belum ada integrasi SIAKAD. Data akademik (fakultas/prodi/mata kuliah/kelas/
jadwal) dikelola lewat SQL langsung (lihat `supabase/seed_prodi_2026.sql`
sebagai contoh) atau Web Admin terpisah - **bukan lagi lewat mobile app**,
menu "Kelola Jadwal" di app sudah dihapus. Akun mahasiswa/dosen didaftarkan
sendiri lewat layar Daftar (role dipilih manual saat registrasi), atau
diprovisioning admin lewat Edge Function `admin-provision-user`.

## 2. Model Liveness (MobileNetV2 real/spoof)

Sesuai kesepakatan: app ini pakai model **pretrained siap pakai** (bukan
training dari nol), dari repo `biometric-technologies/liveness-detection-model`
(MIT license): https://github.com/biometric-technologies/liveness-detection-model/releases/tag/v0.2.0

File `assets/models/model.tflite` sudah ada di project ini. **Preprocessing
di kode Flutter mengikuti kode inferensi ASLI model tersebut (`pixel/255.0`,
skala 0..1)**, BUKAN skema `pixel/127.5-1.0` yang tertulis di draf awal
proposal — bagian metodologi/preprocessing di skripsi perlu direvisi kecil
supaya konsisten dengan kode (kalau butuh bantuan menulis ulang bagian itu,
tinggal minta).

### Kalibrasi (WAJIB sebelum demo/sidang)

Model ini punya satu neuron output sigmoid, dan repo sumbernya tidak
menyebutkan eksplisit arah label (skor tinggi = real atau spoof). Sebelum
dipakai serius:

```bash
pip install tensorflow pillow numpy
python scripts/calibrate_model.py --real contoh_foto/real --spoof contoh_foto/spoof
```

Siapkan folder `contoh_foto/real` (beberapa foto wajah asli, sudah di-crop
mirip wajah) dan `contoh_foto/spoof` (foto dari layar HP/print out, dsb).
Skrip akan menyarankan nilai `realIsHighScore` dan `threshold` yang perlu
di-set di `lib/core/services/liveness_service.dart` (dua konstanta itu sudah
diberi komentar jelas di file tersebut).

## 2b. Model Face Recognition (MobileFaceNet, pencocokan identitas)

Sesuai keputusan pindah ke Opsi A: setelah liveness memastikan wajah di
kamera itu asli (bukan foto/video), sistem JUGA mencocokkan wajah itu
dengan foto referensi yang didaftarkan mahasiswa (WAJIB diisi dulu sebelum
bisa presensi — kalau belum, tombol Clock In di Beranda otomatis nonaktif).
Akses layar pendaftaran wajah: tombol "Daftar Sekarang/Daftar Ulang" di
kartu Beranda, atau tap foto profil di pojok kiri atas drawer.

Model: `mobilefacenet.tflite` dari repo Flutter
`MCarlomagno/FaceRecognitionAuth` (BSD-3-Clause):
https://github.com/MCarlomagno/FaceRecognitionAuth — input wajah 112×112,
preprocessing `(pixel-128)/128`, output embedding 192 dimensi. Dua wajah
dianggap orang yang sama kalau jarak Euclidean antar embedding-nya
`<= 0.5` (nilai default dari repo sumber, konstanta `FaceMatching.threshold`
di `lib/core/utils/face_matching.dart`).

**Kalibrasi**: threshold `0.5` ini nilai umum dari reference repo-nya, BUKAN
hasil pengujian di dataset/device Anda sendiri. Sebelum sidang, uji manual
dengan beberapa mahasiswa (wajah sendiri vs wajah orang lain) dan sesuaikan
konstanta itu kalau perlu — catat proses pengujian ini di bab metodologi
karena relevan sebagai bagian dari pengujian sistem.

## 3. Menjalankan / build APK

Environment build sudah tersedia (Flutter 3.38.7, Android SDK 36).

```bash
flutter pub get
flutter run                 # jalan di device/emulator Android yang terhubung
flutter build apk --release # hasil di build/app/outputs/flutter-apk/app-release.apk
```

Testing di emulator tanpa GPS asli: jalankan emulator, lalu set lokasi palsu
kalau perlu (hanya untuk keperluan log, tidak lagi memengaruhi lolos/gagal
presensi):

```bash
adb emu geo fix <longitude> <latitude>
```

## 4. Struktur proyek singkat

- `lib/core/` — services (auth, lokasi live, face detection ML Kit, liveness
  TFLite, face embedding/matching TFLite) & utils (konversi NV21→RGB, crop
  wajah bersama) & repository Supabase per tabel/fitur.
- `lib/models/` — model data (`UserModel`, `SessionTodayModel`, `IzinModel`,
  `NotifikasiModel`).
- `supabase/migrations/` — skema database (tabel, enum, RLS, trigger, RPC).
- `supabase/functions/` — Edge Functions (logika server-side sensitif seperti
  keputusan presensi & pendaftaran wajah).
- `lib/providers/` — state management (`provider` package).
- `lib/features/` — satu folder per menu/fitur.
- `scripts/calibrate_model.py` — kalibrasi model liveness (lihat di atas).

## 5. Di luar scope purwarupa ini (dicatat, bukan lupa)

- Training model dari nol / dataset asli kampus — bisa ditambahkan belakangan
  kalau butuh, tapi sesuai kesepakatan awal, sesi ini pakai model pretrained.
- Push notification OS-level (FCM/APNs) — menu Notifikasi hanya daftar
  pengumuman dari tabel `notifications`, tanpa push ke luar app.
- Integrasi SIAKAD nyata — data akademik dikelola manual lewat SQL/Web Admin
  terpisah, bukan lewat mobile app.
- Provisioning akun produksi oleh admin — untuk demo, akun mahasiswa/dosen
  didaftarkan sendiri lewat layar Daftar (role dipilih manual saat registrasi).
