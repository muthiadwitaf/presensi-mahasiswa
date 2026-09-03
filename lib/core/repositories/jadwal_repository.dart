import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/jadwal_model.dart';

class JadwalRepository {
  JadwalRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('jadwal');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<List<JadwalModel>> watchAll() {
    return _col.orderBy('hari').snapshots().map(
          (snap) => snap.docs.map((d) => JadwalModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<JadwalModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? JadwalModel.fromMap(doc.id, doc.data()!) : null;
  }

  Future<void> create(JadwalModel jadwal) => _col.add(jadwal.toMap());

  Future<void> update(JadwalModel jadwal) => _col.doc(jadwal.id).update(jadwal.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}
