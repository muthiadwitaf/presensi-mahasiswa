import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/matkul_model.dart';

class MatkulRepository {
  MatkulRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('matkul');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<List<MatkulModel>> watchAll() {
    return _col.orderBy('nama').snapshots().map(
          (snap) => snap.docs.map((d) => MatkulModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<List<MatkulModel>> watchByDosen(String dosenUid) {
    return _col.where('dosenUid', isEqualTo: dosenUid).snapshots().map(
          (snap) => snap.docs.map((d) => MatkulModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> create(MatkulModel matkul) => _col.add(matkul.toMap());

  Future<void> update(MatkulModel matkul) => _col.doc(matkul.id).update(matkul.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}
