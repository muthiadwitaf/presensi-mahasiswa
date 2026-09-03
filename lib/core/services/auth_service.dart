import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';

/// Login mahasiswa/dosen memakai NIM/NIP, bukan email. Firebase Auth tetap
/// dipakai di baliknya lewat email sintetis `"<nim>@presensi.local"` supaya
/// infrastruktur Auth bawaan Firebase (reset password dsb.) tetap bisa
/// dipakai tanpa mahasiswa perlu punya alamat email kampus terdaftar.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static String _syntheticEmail(String nim) => '${nim.trim()}@presensi.local';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel> login({required String nim, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: _syntheticEmail(nim),
      password: password,
    );
    final uid = credential.user!.uid;
    return fetchUserProfile(uid);
  }

  Future<UserModel> register({
    required String nim,
    required String nama,
    required String password,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: _syntheticEmail(nim),
      password: password,
    );
    final uid = credential.user!.uid;
    final user = UserModel(uid: uid, nim: nim.trim(), nama: nama.trim(), role: role);
    await _firestore.collection('users').doc(uid).set(user.toMap());
    return user;
  }

  Future<UserModel> fetchUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw StateError('Profil pengguna tidak ditemukan di Firestore');
    }
    return UserModel.fromMap(uid, doc.data()!);
  }

  Future<void> logout() => _auth.signOut();
}
