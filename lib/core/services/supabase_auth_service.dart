import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../models/user_model.dart';
import '../utils/edge_function_error.dart';

class SupabaseAuthService {
  SupabaseAuthService({sb.SupabaseClient? client}) : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  static String syntheticEmail(String username) => '${username.trim()}@smartattendance.app';

  Stream<sb.AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  sb.User? get currentAuthUser => _client.auth.currentUser;

  Future<UserModel> login({required String username, required String password}) async {
    final result = await _client.auth.signInWithPassword(
      email: syntheticEmail(username),
      password: password,
    );
    final user = result.user;
    if (user == null) {
      throw const sb.AuthException('Login gagal, silakan coba lagi');
    }
    return fetchProfile(user.id);
  }

  Future<UserModel> register({
    required String username,
    required String password,
    required String fullName,
    required UserRole role,
    String? studyProgramId,
    bool isCoordinator = false,
    String? classGroupId,
  }) async {
    if (role != UserRole.mahasiswa && role != UserRole.dosen) {
      throw ArgumentError('Registrasi mandiri hanya untuk mahasiswa/dosen');
    }
    if (isCoordinator && role != UserRole.mahasiswa) {
      throw ArgumentError('Koordinator Kelas berbasis akun mahasiswa');
    }
    if (isCoordinator && classGroupId == null) {
      throw ArgumentError('Kelas yang dikoordinasikan wajib dipilih');
    }
    final res = await _client.auth.signUp(
      email: syntheticEmail(username),
      password: password,
      data: {
        'full_name': fullName.trim(),

        'role': isCoordinator ? 'koordinator_kelas' : role.name,
        'study_program_id': ?studyProgramId,
        'class_group_id': ?classGroupId,
      },
    );
    final user = res.user;
    if (user == null) {
      throw const sb.AuthException('Registrasi gagal, silakan coba lagi');
    }
    if (res.session == null) {

      throw StateError(
        'Registrasi berhasil dibuat tapi sesi tidak aktif. Nonaktifkan '
        '"Confirm email" di pengaturan Supabase Auth.',
      );
    }
    return fetchProfile(user.id);
  }

  Future<UserModel> fetchProfile(String userId) async {
    final row = await _client.from('users').select().eq('id', userId).single();
    return UserModel.fromSupabaseRow(row);
  }

  Future<void> activateAccount({
    required String username,
    required String activationCode,
    required String password,
  }) async {
    final res = await _client.functions.invoke(
      'activate-account',
      body: {
        'username': username.trim(),
        'activation_code': activationCode.trim(),
        'password': password,
      },
    );
    if (res.status != 200) {
      final err = parseEdgeFunctionError(res.data, fallbackMessage: 'Aktivasi akun gagal (${res.status})');
      throw StateError(err.message);
    }
  }

  Future<void> logout() => _client.auth.signOut();
}
