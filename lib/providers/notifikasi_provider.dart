import 'package:flutter/foundation.dart';

import '../core/repositories/notifikasi_repository.dart';
import '../models/notifikasi_model.dart';

class NotifikasiProvider extends ChangeNotifier {
  NotifikasiProvider({NotifikasiRepository? repository}) : _repo = repository ?? NotifikasiRepository();

  final NotifikasiRepository _repo;

  List<NotifikasiModel> items = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> refresh() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      items = await _repo.myNotifications();
    } catch (e) {
      errorMessage = 'Gagal memuat notifikasi: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<TaughtCourseOption>> myTaughtCourseClasses() => _repo.myTaughtCourseClasses();

  Future<bool> buatPengumuman({
    required String judul,
    required String isi,
    required String createdByNama,
    required String targetCourseClassId,
  }) async {
    try {
      await _repo.buat(judul: judul, isi: isi, createdByNama: createdByNama, targetCourseClassId: targetCourseClassId);
      await refresh();
      return true;
    } catch (e) {
      errorMessage = 'Gagal membuat pengumuman: $e';
      notifyListeners();
      return false;
    }
  }
}
