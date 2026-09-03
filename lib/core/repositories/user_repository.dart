import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_model.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('users');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<UserModel?> watchUser(String uid) {
    return _col.doc(uid).snapshots().map(
          (doc) => doc.exists ? UserModel.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _col.doc(uid).get();
    return doc.exists ? UserModel.fromMap(doc.id, doc.data()!) : null;
  }

  Stream<List<UserModel>> watchDosenList() {
    return _col.where('role', isEqualTo: UserRole.dosen.name).snapshots().map(
          (snap) => snap.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> updateFotoWajah(
    String uid, {
    required String base64,
    required List<double> embedding,
    required DateTime updatedAt,
  }) {
    return _col.doc(uid).update({
      'fotoWajahBase64': base64,
      'wajahEmbedding': embedding,
      'fotoWajahUpdatedAt': Timestamp.fromDate(updatedAt),
    });
  }

  Future<void> hapusFotoWajah(String uid) {
    return _col.doc(uid).update({
      'fotoWajahBase64': FieldValue.delete(),
      'wajahEmbedding': FieldValue.delete(),
      'fotoWajahUpdatedAt': FieldValue.delete(),
    });
  }
}
