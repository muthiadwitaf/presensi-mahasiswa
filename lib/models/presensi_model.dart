import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusAkhir { hadir, ditolak }

class PresensiModel {
  final String id;
  final String jadwalId;
  final String matkulNama;
  final String mahasiswaUid;
  final String mahasiswaNama;
  final String mahasiswaNim;
  final DateTime timestamp;
  final double? clockInLat;
  final double? clockInLng;
  final bool statusLiveness;
  final double? livenessConfidence;
  final bool statusFaceMatch;
  final double? faceMatchDistance;
  final StatusAkhir statusAkhir;
  final String? alasanGagal;
  final String? overrideBy;

  /// Clock Out: cukup catat waktu & lokasi (tanpa verifikasi wajah ulang),
  /// null berarti mahasiswa belum clock out untuk sesi ini.
  final DateTime? clockOutAt;
  final double? clockOutLat;
  final double? clockOutLng;

  const PresensiModel({
    required this.id,
    required this.jadwalId,
    required this.matkulNama,
    required this.mahasiswaUid,
    required this.mahasiswaNama,
    required this.mahasiswaNim,
    required this.timestamp,
    this.clockInLat,
    this.clockInLng,
    required this.statusLiveness,
    this.livenessConfidence,
    required this.statusFaceMatch,
    this.faceMatchDistance,
    required this.statusAkhir,
    this.alasanGagal,
    this.overrideBy,
    this.clockOutAt,
    this.clockOutLat,
    this.clockOutLng,
  });

  bool get sudahClockOut => clockOutAt != null;

  factory PresensiModel.fromMap(String id, Map<String, dynamic> map) {
    return PresensiModel(
      id: id,
      jadwalId: map['jadwalId'] as String? ?? '',
      matkulNama: map['matkulNama'] as String? ?? '',
      mahasiswaUid: map['mahasiswaUid'] as String? ?? '',
      mahasiswaNama: map['mahasiswaNama'] as String? ?? '',
      mahasiswaNim: map['mahasiswaNim'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clockInLat: (map['clockInLat'] as num?)?.toDouble(),
      clockInLng: (map['clockInLng'] as num?)?.toDouble(),
      statusLiveness: map['statusLiveness'] as bool? ?? false,
      livenessConfidence: (map['livenessConfidence'] as num?)?.toDouble(),
      statusFaceMatch: map['statusFaceMatch'] as bool? ?? false,
      faceMatchDistance: (map['faceMatchDistance'] as num?)?.toDouble(),
      statusAkhir: (map['statusAkhir'] as String? ?? 'ditolak') == 'hadir'
          ? StatusAkhir.hadir
          : StatusAkhir.ditolak,
      alasanGagal: map['alasanGagal'] as String?,
      overrideBy: map['overrideBy'] as String?,
      clockOutAt: (map['clockOutAt'] as Timestamp?)?.toDate(),
      clockOutLat: (map['clockOutLat'] as num?)?.toDouble(),
      clockOutLng: (map['clockOutLng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jadwalId': jadwalId,
      'matkulNama': matkulNama,
      'mahasiswaUid': mahasiswaUid,
      'mahasiswaNama': mahasiswaNama,
      'mahasiswaNim': mahasiswaNim,
      'timestamp': Timestamp.fromDate(timestamp),
      'clockInLat': clockInLat,
      'clockInLng': clockInLng,
      'statusLiveness': statusLiveness,
      'livenessConfidence': livenessConfidence,
      'statusFaceMatch': statusFaceMatch,
      'faceMatchDistance': faceMatchDistance,
      'statusAkhir': statusAkhir.name,
      'alasanGagal': alasanGagal,
      'overrideBy': overrideBy,
      'clockOutAt': clockOutAt != null ? Timestamp.fromDate(clockOutAt!) : null,
      'clockOutLat': clockOutLat,
      'clockOutLng': clockOutLng,
    };
  }
}
