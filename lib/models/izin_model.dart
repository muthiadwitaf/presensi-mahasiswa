import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusIzin { pending, disetujui, ditolak }

StatusIzin statusIzinFromString(String value) {
  return StatusIzin.values.firstWhere(
    (s) => s.name == value,
    orElse: () => StatusIzin.pending,
  );
}

class IzinModel {
  final String id;
  final String mahasiswaUid;
  final String mahasiswaNama;
  final String mahasiswaNim;
  final String jadwalId;
  final String matkulNama;
  final DateTime tanggal;
  final String alasan;
  final String? buktiBase64;
  final StatusIzin status;
  final DateTime createdAt;

  const IzinModel({
    required this.id,
    required this.mahasiswaUid,
    required this.mahasiswaNama,
    required this.mahasiswaNim,
    required this.jadwalId,
    required this.matkulNama,
    required this.tanggal,
    required this.alasan,
    this.buktiBase64,
    required this.status,
    required this.createdAt,
  });

  factory IzinModel.fromMap(String id, Map<String, dynamic> map) {
    return IzinModel(
      id: id,
      mahasiswaUid: map['mahasiswaUid'] as String? ?? '',
      mahasiswaNama: map['mahasiswaNama'] as String? ?? '',
      mahasiswaNim: map['mahasiswaNim'] as String? ?? '',
      jadwalId: map['jadwalId'] as String? ?? '',
      matkulNama: map['matkulNama'] as String? ?? '',
      tanggal: (map['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now(),
      alasan: map['alasan'] as String? ?? '',
      buktiBase64: map['buktiBase64'] as String?,
      status: statusIzinFromString(map['status'] as String? ?? 'pending'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mahasiswaUid': mahasiswaUid,
      'mahasiswaNama': mahasiswaNama,
      'mahasiswaNim': mahasiswaNim,
      'jadwalId': jadwalId,
      'matkulNama': matkulNama,
      'tanggal': Timestamp.fromDate(tanggal),
      'alasan': alasan,
      'buktiBase64': buktiBase64,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
