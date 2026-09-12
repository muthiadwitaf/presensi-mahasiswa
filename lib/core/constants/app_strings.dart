class AppStrings {
  AppStrings._();

  static const appName = 'AttendU';

  static const gagalLiveness = 'Verifikasi wajah gagal (terdeteksi spoof)';
  static const gagalFaceMatch = 'Wajah tidak cocok dengan data yang terdaftar';
  static const gagalBelumDaftarWajah = 'Anda belum mendaftarkan foto wajah - daftar dulu di Beranda';
  static const gagalTidakAdaSesi = 'Tidak ada sesi mata kuliah yang aktif saat ini';
  static const gagalWajahTidakTerdeteksi = 'Wajah tidak terdeteksi, posisikan wajah di dalam bingkai';
  static const gagalWajahLebihDariSatu = 'Terdeteksi lebih dari satu wajah, pastikan hanya satu wajah berada di dalam kamera';
  static const gagalWajahTerlaluJauh = 'Wajah terlalu jauh, dekatkan wajah ke kamera';
  static const gagalPoseWajah = 'Posisikan wajah lurus menghadap kamera, jangan menoleh atau memiringkan kepala';
  static const gagalWajahTerlaluGelap = 'Pencahayaan terlalu gelap, cari tempat yang lebih terang';
  static const gagalWajahTerlaluTerang = 'Pencahayaan terlalu terang/silau, coba posisi lain';
  static const gagalWajahBuram = 'Gambar wajah buram, pastikan kamera fokus dan tidak bergerak';
  static const berhasilPresensi = 'Presensi berhasil dicatat';
}
