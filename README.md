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
>    hanya direkam sebagai log saat Clock In/Out (field `clockInLat/Lng`,
>    `clockOutLat/Lng` di Firestore), bukan syarat lolos/gagal presensi.
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
  terhubung ke Firestore, `flutter analyze` bersih.
- **Firebase BELUM dikonfigurasi ke project sungguhan** — `lib/firebase_options.dart`
  masih placeholder. APK bisa dibuild & UI bisa dijalankan, tapi
  login/register/semua fitur berbasis data akan gagal sampai langkah di
  bawah dijalankan.
- Model `assets/models/model.tflite` (liveness, MobileNetV2) SUDAH ada —
  **wajib dikalibrasi** sebelum dipakai untuk pengujian/sidang, lihat bagian
  "Model Liveness" di bawah.
- Model `assets/models/mobilefacenet.tflite` (pencocokan identitas wajah)
  SUDAH ada — lihat bagian "Model Face Recognition" di bawah untuk detail &
  catatan kalibrasi threshold-nya.

## 1. Setup Firebase (WAJIB sebelum app bisa dipakai penuh)

Saya tidak bisa membuat project Firebase atas nama Anda (butuh login akun
Google Anda sendiri). Langkahnya:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Ikuti prompt-nya: login akun Google, pilih/buat project Firebase baru, pilih
platform Android saja. Perintah ini akan menimpa `lib/firebase_options.dart`
dan membuat `android/app/google-services.json` otomatis.

Setelah itu, di Firebase Console:
- **Authentication** → Sign-in method → aktifkan **Email/Password** (dipakai
  di balik layar untuk login NIM, lihat `lib/core/services/auth_service.dart`).
- **Firestore Database** → buat database (mode production/test terserah,
  untuk demo skripsi mode test lebih praktis).

Catatan: app ini **tidak pakai Firebase Storage** (Firebase sekarang
mensyaratkan upgrade ke paket Blaze + kartu debit/kredit untuk pakai
Storage). Foto wajah terdaftar & lampiran bukti izin/sakit disimpan sebagai
Base64 terkompresi langsung di dokumen Firestore — lihat
`lib/core/utils/image_compression.dart`. Konsekuensinya resolusi foto lebih
rendah (di-resize maks. 800px, dikompres di bawah ±500KB), tapi cukup untuk
keperluan peninjauan manual, dan tidak perlu kartu pembayaran sama sekali.

### Data awal

Belum ada integrasi SIAKAD, jadi data matkul/ruang/jadwal diisi manual lewat
app: daftar sebagai **dosen** (menu Daftar di halaman login, pilih role
Dosen), lalu buka menu **Kelola Kelas → Kelola Jadwal** untuk menambah Mata
Kuliah, Ruang (nama + gedung saja, tanpa koordinat), dan Jadwal.

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
  wajah bersama, kompresi foto Base64) & repository Firestore per koleksi.
- `lib/models/` — model data (`UserModel`, `JadwalModel`, `RuangModel`,
  `PresensiModel`, `IzinModel`, `NotifikasiModel`).
- `lib/providers/` — state management (`provider` package).
- `lib/features/` — satu folder per menu/fitur.
- `scripts/calibrate_model.py` — kalibrasi model liveness (lihat di atas).

## 5. Di luar scope purwarupa ini (dicatat, bukan lupa)

- Training model dari nol / dataset asli kampus — bisa ditambahkan belakangan
  kalau butuh, tapi sesuai kesepakatan awal, sesi ini pakai model pretrained.
- Push notification OS-level (FCM) — menu Notifikasi hanya daftar pengumuman
  dari Firestore, tanpa push ke luar app.
- Integrasi SIAKAD nyata — jadwal/matkul dikelola manual lewat menu Kelola
  Jadwal (role dosen).
- Provisioning akun produksi oleh admin — untuk demo, akun mahasiswa/dosen
  didaftarkan sendiri lewat layar Daftar (role dipilih manual saat registrasi).
