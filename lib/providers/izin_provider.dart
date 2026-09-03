import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/repositories/izin_repository.dart';
import '../core/utils/image_compression.dart';
import '../models/izin_model.dart';

class IzinProvider extends ChangeNotifier {
  IzinProvider({IzinRepository? izinRepository})
      : _izinRepo = izinRepository ?? IzinRepository();

  final IzinRepository _izinRepo;

  bool isSubmitting = false;
  String? errorMessage;

  Stream<List<IzinModel>> watchByMahasiswa(String uid) => _izinRepo.watchByMahasiswa(uid);
  Stream<List<IzinModel>> watchPending() => _izinRepo.watchPending();

  Future<bool> ajukanIzin({
    required String mahasiswaUid,
    required String mahasiswaNama,
    required String mahasiswaNim,
    required String jadwalId,
    required String matkulNama,
    required DateTime tanggal,
    required String alasan,
    File? bukti,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      String? buktiBase64;
      if (bukti != null) {
        buktiBase64 = await ImageCompression.compressToBase64(bukti);
      }
      final izin = IzinModel(
        id: '',
        mahasiswaUid: mahasiswaUid,
        mahasiswaNama: mahasiswaNama,
        mahasiswaNim: mahasiswaNim,
        jadwalId: jadwalId,
        matkulNama: matkulNama,
        tanggal: tanggal,
        alasan: alasan,
        buktiBase64: buktiBase64,
        status: StatusIzin.pending,
        createdAt: DateTime.now(),
      );
      await _izinRepo.ajukan(izin);
      return true;
    } catch (e) {
      errorMessage = 'Gagal mengajukan izin: $e';
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> putuskan(String izinId, StatusIzin status) => _izinRepo.putuskan(izinId, status);
}
