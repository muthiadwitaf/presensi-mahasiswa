import 'package:flutter/foundation.dart';

import '../core/repositories/schedule_repository.dart';
import '../models/session_today_model.dart';

/// Sumber data jadwal untuk Beranda - dibangun dari `resolve_class_days`
/// (jadwal template + meeting session aktual, lihat migration
/// `0008_schedules_sessions.sql`) lewat Supabase, BUKAN koleksi Firestore
/// statis seperti sebelumnya. CRUD matkul/ruang/jadwal manual yang dulu ada
/// di sini sudah dihapus - pengelolaan jadwal akademik sekarang wewenang Web
/// Admin terpisah (lihat keputusan migrasi di percakapan ini), bukan mobile.
///
/// Tidak ada realtime stream (Postgres bukan Firestore) - panggil [refresh]
/// saat pull-to-refresh atau berkala.
class JadwalProvider extends ChangeNotifier {
  JadwalProvider({ScheduleRepository? repository}) : _repo = repository ?? ScheduleRepository();

  final ScheduleRepository _repo;

  List<SessionToday> sesiMahasiswaHariIni = [];
  List<SessionToday> sesiDosenHariIni = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> refreshMahasiswa() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      sesiMahasiswaHariIni = await _repo.sessionsForStudentOn(DateTime.now());
    } catch (e) {
      errorMessage = 'Gagal memuat jadwal: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDosen() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      sesiDosenHariIni = await _repo.sessionsForLecturerOn(DateTime.now());
    } catch (e) {
      errorMessage = 'Gagal memuat jadwal: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Sesi mahasiswa yang jendela jam-nya aktif sekarang - dipakai untuk
  /// mengaktifkan tombol Clock In. Jendela buka/tutup presensi yang
  /// sesungguhnya tetap dihitung server-side saat submit-attendance; ini
  /// hanya kondisi tampilan.
  SessionToday? sesiAktifSekarang() {
    for (final s in sesiMahasiswaHariIni) {
      if (s.isActiveNow()) return s;
    }
    return null;
  }
}
