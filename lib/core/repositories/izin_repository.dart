import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/izin_model.dart';

class IzinRepository {
  IzinRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('izin');

  final CollectionReference<Map<String, dynamic>> _col;

  Future<void> ajukan(IzinModel izin) => _col.add(izin.toMap());

  Stream<List<IzinModel>> watchByMahasiswa(String mahasiswaUid) {
    return _col
        .where('mahasiswaUid', isEqualTo: mahasiswaUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => IzinModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<IzinModel>> watchPending() {
    return _col
        .where('status', isEqualTo: StatusIzin.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => IzinModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> putuskan(String izinId, StatusIzin status) {
    return _col.doc(izinId).update({'status': status.name});
  }
}
