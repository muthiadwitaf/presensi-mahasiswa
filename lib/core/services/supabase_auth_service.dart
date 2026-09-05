import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../models/user_model.dart';

/// Login/registrasi mahasiswa/dosen memakai NIM/NIP lewat Supabase Auth,
/// dengan email sintetis supaya tidak perlu alamat email kampus terdaftar.
///
/// PENTING: domain HARUS berakhiran TLD publik yang dikenali (mis. `.com`,
/// `.app`) - GoTrue (Supabase Auth) menolak domain seperti `.local` atau
/// TLD/domain yang tidak pernah terdaftar (`smartattendance.id` ditolak
/// dengan `email_address_invalid` walau formatnya benar). Sudah diverifikasi
/// lewat percobaan langsung ke endpoint `/auth/v1/signup`.
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

  /// Registrasi mandiri - role DIPILIH BEBAS oleh pengguna (mahasiswa/dosen).
  /// Ini keputusan produk yang diterima secara sadar walau berlawanan dengan
  /// prinsip "role tidak boleh dipilih bebas saat registrasi" - lihat catatan
  /// di `supabase/migrations/0018_self_registration_and_coordinator.sql`.
  /// Trigger DB (`app.handle_new_auth_user`) yang membuat baris `users` +
  /// `students`/`lecturers`, bukan kode Dart ini - RLS tidak memberi client
  /// hak insert langsung ke tabel-tabel itu.
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
        // "koordinator_kelas" bukan nilai users.role (tetap mahasiswa di DB)
        // - trigger app.handle_new_auth_user yang menerjemahkannya jadi
        // role dasar mahasiswa + baris role_assignments, lihat migration
        // 0024_self_register_coordinator.sql.
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
      // Proyek Supabase mewajibkan konfirmasi email - tidak akan pernah
      // sampai karena email di sini sintetis. Harus dimatikan di
      // Authentication > Providers > Email > "Confirm email".
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

  /// Mengaktifkan akun yang sudah diprovisioning admin (lihat
  /// `supabase/functions/activate-account`). Body request TIDAK memuat
  /// role - server mengambilnya dari baris `provisioned_accounts` yang
  /// dibuat admin, bukan dari input pengguna.
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
      throw StateError(_extractErrorMessage(res.data) ?? 'Aktivasi akun gagal (${res.status})');
    }
  }

  Future<void> logout() => _client.auth.signOut();

  String? _extractErrorMessage(dynamic data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
