import 'package:cloud_firestore/cloud_firestore.dart';

class NotifikasiModel {
  final String id;
  final String judul;
  final String isi;
  final String createdByNama;
  final DateTime createdAt;

  const NotifikasiModel({
    required this.id,
    required this.judul,
    required this.isi,
    required this.createdByNama,
    required this.createdAt,
  });

  factory NotifikasiModel.fromMap(String id, Map<String, dynamic> map) {
    return NotifikasiModel(
      id: id,
      judul: map['judul'] as String? ?? '',
      isi: map['isi'] as String? ?? '',
      createdByNama: map['createdByNama'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'judul': judul,
      'isi': isi,
      'createdByNama': createdByNama,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
