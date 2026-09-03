import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/ruang_model.dart';

class RuangRepository {
  RuangRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('ruang');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<List<RuangModel>> watchAll() {
    return _col.orderBy('nama').snapshots().map(
          (snap) => snap.docs.map((d) => RuangModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<RuangModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? RuangModel.fromMap(doc.id, doc.data()!) : null;
  }

  Future<void> create(RuangModel ruang) => _col.add(ruang.toMap());

  Future<void> update(RuangModel ruang) => _col.doc(ruang.id).update(ruang.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}
