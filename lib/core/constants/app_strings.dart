/// Kumpulan string UI berbahasa Indonesia dipakai lintas fitur, supaya
/// konsisten dan gampang direvisi di satu tempat.
class AppStrings {
  AppStrings._();

  static const appName = 'AttendU';

  static const gagalLiveness = 'Verifikasi wajah gagal (terdeteksi spoof)';
  static const gagalFaceMatch = 'Wajah tidak cocok dengan data yang terdaftar';
  static const gagalBelumDaftarWajah = 'Anda belum mendaftarkan foto wajah - daftar dulu di Beranda';
  static const gagalTidakAdaSesi = 'Tidak ada sesi mata kuliah yang aktif saat ini';
  static const gagalWajahTidakTerdeteksi = 'Wajah tidak terdeteksi, posisikan wajah di dalam bingkai';
  static const berhasilPresensi = 'Presensi berhasil dicatat';
}
