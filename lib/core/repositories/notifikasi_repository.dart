import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/notifikasi_model.dart';

class NotifikasiRepository {
  NotifikasiRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('notifikasi');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<List<NotifikasiModel>> watchAll() {
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => NotifikasiModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> buat(NotifikasiModel notifikasi) => _col.add(notifikasi.toMap());
}
