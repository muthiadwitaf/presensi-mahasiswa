import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/repositories/jadwal_repository.dart';
import '../core/repositories/matkul_repository.dart';
import '../core/repositories/ruang_repository.dart';
import '../models/jadwal_model.dart';
import '../models/matkul_model.dart';
import '../models/ruang_model.dart';

/// Menyediakan data jadwal kuliah, matkul, dan ruang (dengan koordinat
/// geofence) untuk seluruh app — dipakai oleh Beranda/Sesi Aktif, Jadwal
/// Kuliah, dan Kelola Jadwal (role dosen).
class JadwalProvider extends ChangeNotifier {
  JadwalProvider({
    JadwalRepository? jadwalRepository,
    MatkulRepository? matkulRepository,
    RuangRepository? ruangRepository,
  })  : _jadwalRepo = jadwalRepository ?? JadwalRepository(),
        _matkulRepo = matkulRepository ?? MatkulRepository(),
        _ruangRepo = ruangRepository ?? RuangRepository() {
    _jadwalSub = _jadwalRepo.watchAll().listen((v) {
      jadwalList = v;
      notifyListeners();
    });
    _matkulSub = _matkulRepo.watchAll().listen((v) {
      matkulList = v;
      notifyListeners();
    });
    _ruangSub = _ruangRepo.watchAll().listen((v) {
      ruangList = v;
      notifyListeners();
    });
  }

  final JadwalRepository _jadwalRepo;
  final MatkulRepository _matkulRepo;
  final RuangRepository _ruangRepo;

  late final StreamSubscription<List<JadwalModel>> _jadwalSub;
  late final StreamSubscription<List<MatkulModel>> _matkulSub;
  late final StreamSubscription<List<RuangModel>> _ruangSub;

  List<JadwalModel> jadwalList = [];
  List<MatkulModel> matkulList = [];
  List<RuangModel> ruangList = [];

  RuangModel? ruangById(String id) {
    for (final r in ruangList) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Sesi yang jendela waktunya aktif sekarang (KF-04 & alur presensi
  /// bergantung pada ini: tombol presensi hanya aktif kalau ada sesi aktif).
  JadwalModel? sesiAktifSekarang() {
    final now = DateTime.now();
    for (final j in jadwalList) {
      if (j.isActiveAt(now)) return j;
    }
    return null;
  }

  List<JadwalModel> sesiHariIni() {
    final now = DateTime.now();
    return jadwalList.where((j) => j.hari == now.weekday).toList()
      ..sort((a, b) => a.jamMulai.compareTo(b.jamMulai));
  }

  // ---- CRUD (role dosen, Kelola Jadwal) ----
  Future<void> tambahMatkul(MatkulModel m) => _matkulRepo.create(m);
  Future<void> hapusMatkul(String id) => _matkulRepo.delete(id);

  Future<void> tambahRuang(RuangModel r) => _ruangRepo.create(r);
  Future<void> hapusRuang(String id) => _ruangRepo.delete(id);

  Future<void> tambahJadwal(JadwalModel j) => _jadwalRepo.create(j);
  Future<void> hapusJadwal(String id) => _jadwalRepo.delete(id);

  @override
  void dispose() {
    _jadwalSub.cancel();
    _matkulSub.cancel();
    _ruangSub.cancel();
    super.dispose();
  }
}
