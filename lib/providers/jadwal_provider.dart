import 'package:flutter/foundation.dart';

import '../core/repositories/schedule_repository.dart';
import '../models/session_today_model.dart';

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

  SessionToday? sesiAktifSekarang() {
    for (final s in sesiMahasiswaHariIni) {
      if (s.isActiveNow()) return s;
    }
    return null;
  }
}
