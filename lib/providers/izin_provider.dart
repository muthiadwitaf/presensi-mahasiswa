import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/repositories/izin_repository.dart';
import '../core/repositories/schedule_repository.dart';
import '../models/izin_model.dart';

class IzinProvider extends ChangeNotifier {
  IzinProvider({IzinRepository? izinRepository, ScheduleRepository? scheduleRepository})
      : _izinRepo = izinRepository ?? IzinRepository(),
        _scheduleRepo = scheduleRepository ?? ScheduleRepository();

  final IzinRepository _izinRepo;
  final ScheduleRepository _scheduleRepo;

  /// Mata kuliah aktif mahasiswa, untuk dropdown pilihan pada form izin.
  Future<List<EnrolledCourseOption>> activeCourseOptions() => _scheduleRepo.myActiveCourseClasses();

  List<IzinModel> mine = [];
  List<IzinModel> pending = [];
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;

  Future<void> refreshMine() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      mine = await _izinRepo.myLeaveRequests();
    } catch (e) {
      errorMessage = 'Gagal memuat data izin: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPending() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      pending = await _izinRepo.pendingForLecturer();
    } catch (e) {
      errorMessage = 'Gagal memuat data izin: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> ajukanIzin({
    required String jadwalId,
    required JenisIzin jenis,
    required DateTime tanggal,
    required String alasan,
    File? bukti,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _izinRepo.ajukan(courseClassId: jadwalId, jenis: jenis, tanggal: tanggal, alasan: alasan, bukti: bukti);
      await refreshMine();
      return true;
    } catch (e) {
      errorMessage = 'Gagal mengajukan izin: $e';
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> putuskan(String izinId, StatusIzin status) async {
    await _izinRepo.putuskan(izinId, status);
    await refreshPending();
  }

  Future<String> attachmentSignedUrl(String path) => _izinRepo.attachmentSignedUrl(path);
}
