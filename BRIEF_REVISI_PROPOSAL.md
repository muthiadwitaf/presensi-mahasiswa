# Brief: Revisi Proposal Skripsi Sesuai Kode Terbaru

Dokumen ini ringkasan lengkap supaya sesi Claude yang baru bisa langsung
merevisi proposal skripsi tanpa perlu penjelasan ulang dari saya. Tugasnya:
**revisi `Proposal_Skripsi_Sistem_Presensi_Liveness_Geofencing.docx` supaya
konsisten dengan implementasi kode yang sudah jadi**, karena beberapa
keputusan berubah signifikan selama proses coding dan sekarang bertentangan
dengan apa yang tertulis di proposal.

## Identitas & lokasi file

- Mahasiswa: Muthi'ah Dwita Fathinah, NIM 2301030013, Teknik Informatika,
  Universitas Saintek Muhammadiyah Jakarta. Dosen pembimbing: Bapak Fitrah
  Juliansyah.
- Proposal: `C:\Users\USer\Downloads\Proposal_Skripsi_Sistem_Presensi_Liveness_Geofencing.docx`
- Kode aplikasi (Flutter): `C:\tugas-akhir2` — baca `README.md` di root
  project ini juga, ada catatan serupa di bagian atasnya.

## Kondisi proposal saat ini (sebelum direvisi)

Proposal sudah pernah direvisi sesi Claude sebelumnya untuk pivot topik dari
"deteksi masker di Puskesmas" ke "presensi liveness + geofencing" ini. Ada
beberapa catatan (komentar Word) tertinggal dari sesi itu yang masih relevan:

1. Pivot topik ini (setelah bimbingan ke-3) belum dikonfirmasi ulang ke
   dosen pembimbing — perlu diingatkan ke user kalau belum dilakukan.
2. Bab III Profil Instansi (3.1.1 Sejarah, 3.1.2 Visi Misi, 3.1.3 Struktur
   Organisasi, 3.1.5 Sarana Prasarana) masih placeholder `[CATATAN: ...]`
   karena tidak ada data resmi kampus. Gambar 2.4, 2.5, 2.7, 2.9 masih
   gambar versi lama (Puskesmas/deteksi masker), perlu digambar ulang.
3. Sub-bab teori baru 2.2.13 (Liveness Detection dan Anti-Spoofing) dan
   2.2.14 (Geofencing dan Location-Based Service) belum punya sitasi
   akademik (jurnal/buku) - perlu ditambahkan, konsisten dengan gaya
   sitasi bagian lain.
4. Beberapa permintaan formatting belum dikerjakan: urutan alfabetis Bab
   II, penomoran ulang Gambar/Tabel Bab III mulai 3.1, pemindahan tabel
   Penelitian Terdahulu + pembatasan 5 entri + referensi jurnal 5 tahun
   terakhir dengan link, tabel pedoman wawancara/observasi di 3.3.4, ukuran
   font Daftar Isi.

## PERUBAHAN UTAMA yang harus direvisi di proposal

### 1. Face recognition ditambahkan (pivot dari "Opsi B" ke "Opsi A")

Proposal SAAT INI menulis (kutipan langsung):
- **Batasan Masalah**: *"identifikasi identitas mahasiswa pada penelitian
  ini masih memanfaatkan kombinasi login akun (NIM) dengan satu foto
  referensi wajah yang telah didaftarkan, **belum mencakup pengembangan
  model pengenalan wajah (face recognition)** yang mampu mengidentifikasi
  identitas mahasiswa dari banyak wajah terdaftar secara otomatis."*
- **Saran**: face recognition penuh diposisikan sebagai PR peneliti
  selanjutnya: *"...baik melalui penyempurnaan model pengenalan wajah
  (face recognition) penuh, peningkatan performa liveness detection..."*
- **Latar Belakang**: ada paragraf membandingkan dengan app HR tempat kerja
  penulis (hr.mtxapp.cloud), memposisikan app ini lebih unggul karena
  *transparan* soal metode verifikasi (bukan karena punya face recognition).

**Kondisi kode sekarang**: Face recognition SUDAH ditambahkan dan berjalan.
Alasan pivot: user membandingkan dengan app HR kantornya sendiri
(hr.mtxapp.cloud) yang ternyata melakukan pencocokan wajah otomatis
(bukan cuma liveness), dan user memutuskan ikut menambahkannya meski sudah
diperingatkan soal konflik dengan proposal ini.

Detail teknis untuk ditulis di bab metodologi:
- Model: **MobileFaceNet** (`.tflite`), sumber:
  `MCarlomagno/FaceRecognitionAuth` (GitHub, lisensi BSD-3-Clause) —
  https://github.com/MCarlomagno/FaceRecognitionAuth
- Input: wajah 112×112 piksel, preprocessing `(pixel - 128) / 128`.
- Output: embedding 192 dimensi.
- Metode pencocokan: **jarak Euclidean** antar dua embedding, threshold
  `<= 0.5` (nilai default dari repo sumber — belum dikalibrasi ulang oleh
  user sendiri, catat sebagai keterbatasan penelitian kalau belum sempat).
- Alur: liveness (MobileNetV2) LEBIH DULU memastikan wajah live/asli, BARU
  KEMUDIAN wajah yang sama itu dicocokkan (MobileFaceNet) dengan foto
  referensi yang didaftarkan mahasiswa di awal. Kedua model tetap
  **pretrained** (bukan hasil training sendiri) — lihat poin 3.

**Yang perlu direvisi**: Latar Belakang (posisikan ulang argumen
pembanding dengan app HR — app ini sekarang punya face recognition JUGA,
jadi pembeda utamanya bukan lagi "kami tidak pakai face recognition, cukup
liveness+NIM" tapi lebih ke transparansi status verifikasi ke pengguna +
kombinasi liveness sebagai lapis anti-spoofing tambahan yang tidak
disebutkan ada di app HR tsb), Rumusan Masalah/Tujuan (tambahkan tujuan
terkait pencocokan identitas wajah), Batasan Masalah (hapus/ubah kalimat
yang bilang face recognition tidak dicakup), Saran (hapus/ubah poin yang
memposisikan face recognition sebagai future work — mungkin ganti dengan
poin lain, mis. kalibrasi threshold pencocokan wajah yang lebih rigorous).

### 2. Geofencing — SUDAH diputuskan: tetap dipakai, kode & judul konsisten

**Update (2026-09-11): keputusan ini sudah final — geofencing TETAP
dipakai.** Catatan versi lama di bawah ini (yang bilang validasi radius
"dihapus total") sudah tidak berlaku dan sempat menyebabkan `README.md`
mengklaim hal yang bertentangan dengan kode — sudah diperbaiki.

**Kondisi kode sekarang (verifikasi ulang dari `supabase/functions/
submit-attendance/index.ts`)**: validasi radius geofence **aktif dan
mengikat** — presensi ditolak (`FAIL_GEOFENCE`) kalau mahasiswa di luar
radius, akurasi GPS terlalu buruk, atau lokasi terdeteksi mock. Detail
teknis untuk ditulis di bab metodologi (lihat juga bagian "Geofencing" di
`README.md`):
- Metode jarak: **Haversine**, dihitung server-side di edge function
  `submit-attendance`.
- Radius: per-lokasi (`locations.radius_meters`, 10–5000 m) dengan
  fallback ke setting global `geofence_radius_meters` (default 150 m).
- Toleransi akurasi GPS: default 50 m (`geofence_gps_accuracy_max_meters`).
- Deteksi mock location: presensi ditolak kalau device melaporkan lokasi
  palsu (`is_mocked`).
- Sesi `ONLINE` di-skip dari validasi radius secara default (tidak relevan
  secara lokasi fisik); sesi `OFFLINE`/`HYBRID` selalu wajib kirim lokasi
  dan tervalidasi radius, kecuali sesi/lokasi tertentu memang diset untuk
  tidak menegakkan geofencing (`require_geofence=false` per sesi atau
  `is_geofenced=false` per lokasi).

**Implikasi ke proposal**: judul skripsi **tidak perlu diubah** — istilah
"Geofencing" tetap akurat secara teknis karena validasi radius memang
berjalan. Proposal (KF-04 & pembahasan terkait) yang sudah menjelaskan
geofencing sebagai validasi radius **sudah sesuai** dengan kode; yang
perlu ditambahkan hanyalah detail implementasi di atas (radius default,
metode Haversine, aturan per mode ONLINE/OFFLINE) di bab metodologi, dan
sebutkan bahwa nilai radius & tolerable GPS accuracy adalah parameter yang
bisa dikonfigurasi (bukan hardcode tunggal) — relevan untuk pembahasan
keterbatasan/pengujian.

### 3. Preprocessing model liveness berubah

Proposal menulis skema preprocessing: *"(piksel / 127,5) - 1,0 sehingga
berada pada rentang -1,0 s.d. 1,0"*.

**Kondisi kode sekarang**: preprocessing yang benar-benar dipakai adalah
**`pixel / 255.0`** (rentang 0..1), mengikuti kode inferensi asli model
pretrained yang dipakai (lihat poin 4). Ini perlu diralat di bab
metodologi/preprocessing.

### 4. Model liveness: pretrained, bukan training dari nol

Proposal (bagian dataset) merencanakan training sendiri: ±1.500 citra real
+ ±1.500 citra spoof (dataset publik + dokumentasi lapangan) + 300 citra
data uji.

**Kondisi kode sekarang**: model MobileNetV2 liveness **pretrained**,
sumber: `biometric-technologies/liveness-detection-model` (GitHub, lisensi
MIT), release v0.2.0 — https://github.com/biometric-technologies/liveness-detection-model/releases/tag/v0.2.0
File `model.tflite` (~9MB). Output: satu neuron sigmoid (bukan softmax 2
kelas), threshold `0.5`, arah label (`realIsHighScore`) BELUM divalidasi
dari dokumentasi resmi model — masih asumsi, perlu dikalibrasi manual
(skrip `scripts/calibrate_model.py` di kode sudah disiapkan untuk ini,
tapi user belum menjalankannya per laporan terakhir).

**Implikasi untuk proposal**: bagian dataset training (1500+1500+300 citra)
kemungkinan besar TIDAK RELEVAN lagi kalau model tetap pretrained sampai
akhir — perlu diputuskan: (a) proposal diubah supaya tidak menjanjikan
training dari nol (fokus ke integrasi model pretrained + pengujian
performa di device asli), atau (b) user memang berencana training sendiri
nanti sebelum sidang (kalau begitu, dataset section boleh dipertahankan
tapi tandai jelas kalau kode belum mengimplementasikan ini).
**Tanyakan ke user mana yang benar** sebelum merevisi bagian ini — jangan
diasumsikan.

### 5. Fitur Clock In / Clock Out ditambahkan

Proposal/KF asli hanya menyebut "presensi dicatat" satu kali per sesi.
Kode sekarang punya alur dua tahap:
- **Clock In**: alur penuh (cek wajah terdaftar → liveness → pencocokan
  wajah → catat waktu+lokasi). Ini yang jadi pemenuhan KF inti.
- **Clock Out**: ringan, HANYA catat waktu+lokasi (tanpa verifikasi
  wajah/liveness ulang), bisa dilakukan kapan saja selama jendela waktu
  sesi masih berlangsung.

Ini kemungkinan cukup ditambahkan sebagai KF baru / penyempurnaan alur,
tidak bertentangan dengan tujuan penelitian, tapi perlu disebutkan di
bagian fungsional/alur sistem supaya proposal & kode sinkron.

### 6. Wajah Terdaftar: dari "bukan face recognition" jadi WAJIB untuk matching

Sebelumnya (Opsi B) fitur "Wajah Terdaftar" cuma penyimpanan referensi
untuk peninjauan manual dosen (bukan dipakai sistem otomatis). Sekarang
foto itu WAJIB didaftarkan dulu (jadi prasyarat sebelum bisa Clock In sama
sekali) dan dipakai langsung oleh sistem untuk pencocokan otomatis (poin
1). Pastikan bagian yang menjelaskan fitur ini di proposal (kalau ada)
diperbarui.

## Hal-hal yang TIDAK berubah (tetap sesuai proposal)

- Login pakai NIM (bukan email) — tetap.
- Kombinasi 3 lapis verifikasi disebutkan di proposal (NIM, geofencing,
  liveness) — sekarang secara teknis jadi "NIM + liveness + face matching
  + pencatatan lokasi", jadi kalimat yang menyebut "3 lapis" ini juga perlu
  disesuaikan (sekarang lebih akurat disebut 4 komponen, atau reposisi
  "lokasi" bukan sebagai lapis validasi tapi sebagai data pelengkap log).
- Database: Firebase (Firestore + Authentication). TIDAK pakai Firebase
  Storage (butuh upgrade paket Blaze/kartu kredit) — foto disimpan sebagai
  Base64 langsung di Firestore. Ini detail implementasi, kemungkinan tidak
  perlu masuk proposal kecuali proposal secara spesifik menyebut Firebase
  Storage.
- Metodologi pengembangan: Prototyping — tetap.
- Google ML Kit Face Detection (`FaceDetectorMode.fast`, `minFaceSize 0.15`)
  untuk deteksi bounding box wajah — tetap dipakai apa adanya, tidak
  berubah.
- Purwarupa berdiri sendiri, belum integrasi SIAKAD — tetap.
- Objek penelitian: Universitas Saintek Muhammadiyah Jakarta — tetap.

## Instruksi untuk sesi Claude berikutnya

1. **Baca dulu** `C:\tugas-akhir2\README.md` (ada catatan ringkas serupa di
   bagian atas) dan file ini secara keseluruhan sebelum mulai edit.
2. **Konfirmasi ke user dulu** (jangan langsung eksekusi) untuk dua hal
   yang butuh keputusan akademis: (a) soal judul/istilah "geofencing" vs
   "pencatatan lokasi" (poin 2 di atas), dan (b) soal dataset training vs
   tetap pretrained (poin 4 di atas). Selebihnya boleh langsung direvisi
   mengikuti kondisi kode karena sudah jelas.
3. Gunakan skill `docx` (unpack → edit `word/document.xml` → repack, atau
   ikuti workflow yang skill itu jelaskan) untuk mengedit
   `Proposal_Skripsi_Sistem_Presensi_Liveness_Geofencing.docx` di tempat
   (bukan bikin file baru dari nol) — dokumen ini punya struktur, gaya,
   komentar, dan sitasi yang sudah ada, jangan sampai rusak.
4. Ingatkan user soal 4 catatan tertinggal dari sesi sebelumnya (bagian
   "Kondisi proposal saat ini" di atas) kalau belum ditindaklanjuti,
   terutama soal konfirmasi pivot topik ke dosen pembimbing.
5. Setelah revisi, render ke PDF dan screenshot untuk verifikasi visual
   sebelum melaporkan selesai ke user (ikuti langkah "Verify the output" di
   skill docx).
