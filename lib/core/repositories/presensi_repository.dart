import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/presensi_model.dart';

class PresensiRepository {
  PresensiRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('presensi');

  final CollectionReference<Map<String, dynamic>> _col;

  Future<void> catat(PresensiModel presensi) => _col.add(presensi.toMap());

  Stream<List<PresensiModel>> watchByMahasiswa(String mahasiswaUid) {
    return _col
        .where('mahasiswaUid', isEqualTo: mahasiswaUid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PresensiModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<PresensiModel>> watchByJadwal(String jadwalId) {
    return _col
        .where('jadwalId', isEqualTo: jadwalId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PresensiModel.fromMap(d.id, d.data())).toList());
  }

  /// Cek apakah mahasiswa sudah presensi (dengan status hadir) untuk jadwal
  /// & tanggal (hari ini) tertentu — mencegah presensi dobel dalam satu sesi.
  Future<bool> sudahPresensiHariIni({
    required String mahasiswaUid,
    required String jadwalId,
  }) async {
    final snap = await _queryHariIni(mahasiswaUid: mahasiswaUid, jadwalId: jadwalId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  /// Live status Clock In/Clock Out mahasiswa untuk sesi (jadwal) & hari ini
  /// — dipakai Beranda untuk memutuskan tombol mana yang ditampilkan.
  Stream<PresensiModel?> watchPresensiHariIni({
    required String mahasiswaUid,
    required String jadwalId,
  }) {
    return _queryHariIni(mahasiswaUid: mahasiswaUid, jadwalId: jadwalId).limit(1).snapshots().map(
          (snap) => snap.docs.isEmpty ? null : PresensiModel.fromMap(snap.docs.first.id, snap.docs.first.data()),
        );
  }

  Query<Map<String, dynamic>> _queryHariIni({
    required String mahasiswaUid,
    required String jadwalId,
  }) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _col
        .where('mahasiswaUid', isEqualTo: mahasiswaUid)
        .where('jadwalId', isEqualTo: jadwalId)
        .where('statusAkhir', isEqualTo: StatusAkhir.hadir.name)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
  }

  Future<void> overrideManual({
    required String presensiId,
    required String dosenUid,
  }) {
    return _col.doc(presensiId).update({
      'statusAkhir': StatusAkhir.hadir.name,
      'overrideBy': dosenUid,
    });
  }

  Future<void> catatClockOut(
    String presensiId, {
    required DateTime waktu,
    required double lat,
    required double lng,
  }) {
    return _col.doc(presensiId).update({
      'clockOutAt': Timestamp.fromDate(waktu),
      'clockOutLat': lat,
      'clockOutLng': lng,
    });
  }
}
