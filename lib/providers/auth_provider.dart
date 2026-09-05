import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/services/supabase_auth_service.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthProvider extends ChangeNotifier {
  AuthProvider({SupabaseAuthService? authService}) : _authService = authService ?? SupabaseAuthService() {
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
    _bootstrap();
  }

  final SupabaseAuthService _authService;
  late final StreamSubscription<sb.AuthState> _authSub;

  AuthStatus status = AuthStatus.unknown;
  UserModel? currentUser;
  String? errorMessage;
  bool isBusy = false;

  /// Sesi Supabase bisa saja sudah ada (dari penyimpanan lokal) sebelum
  /// listener `onAuthStateChange` pertama kali terpanggil - tanpa ini,
  /// status akan nyangkut di [AuthStatus.unknown] pada cold start.
  Future<void> _bootstrap() async {
    final user = _authService.currentAuthUser;
    if (user == null) {
      status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }
    await _loadProfile(user.id);
  }

  Future<void> _onAuthChanged(sb.AuthState state) async {
    final user = state.session?.user;
    if (user == null) {
      status = AuthStatus.loggedOut;
      currentUser = null;
      notifyListeners();
      return;
    }
    await _loadProfile(user.id);
  }

  Future<void> _loadProfile(String userId) async {
    try {
      currentUser = await _authService.fetchProfile(userId);
      status = AuthStatus.loggedIn;
    } catch (_) {
      // Auth berhasil tapi profil di tabel `users` tidak ditemukan/terbaca
      // (mis. RLS, atau baris belum sempat dibuat trigger) - jangan
      // anggap loggedIn tanpa profil yang valid.
      status = AuthStatus.loggedOut;
      currentUser = null;
    }
    notifyListeners();
  }

  Future<bool> login({required String nim, required String password}) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      currentUser = await _authService.login(username: nim, password: password);
      status = AuthStatus.loggedIn;
      return true;
    } on sb.AuthException catch (e) {
      errorMessage = _pesanErrorAuth(e.message);
      return false;
    } catch (e) {
      errorMessage = 'Login gagal: $e';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Mengaktifkan akun yang sudah diprovisioning admin, lalu langsung login.
  /// Menggantikan `register()` lama - tidak ada parameter role di sini
  /// secara sengaja, lihat `SupabaseAuthService.activateAccount`.
  Future<bool> activateAccount({
    required String nim,
    required String activationCode,
    required String password,
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.activateAccount(
        username: nim,
        activationCode: activationCode,
        password: password,
      );
    } catch (e) {
      errorMessage = 'Aktivasi akun gagal: $e';
      isBusy = false;
      notifyListeners();
      return false;
    }
    isBusy = false;
    return login(nim: nim, password: password);
  }

  /// Registrasi mandiri, role dipilih pengguna sendiri (mahasiswa/dosen) -
  /// lihat catatan keamanan di `SupabaseAuthService.register`.
  Future<bool> register({
    required String nim,
    required String nama,
    required String password,
    required UserRole role,
    String? studyProgramId,
    bool isCoordinator = false,
    String? classGroupId,
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      currentUser = await _authService.register(
        username: nim,
        password: password,
        fullName: nama,
        role: role,
        studyProgramId: studyProgramId,
        isCoordinator: isCoordinator,
        classGroupId: classGroupId,
      );
      status = AuthStatus.loggedIn;
      return true;
    } on sb.AuthException catch (e) {
      errorMessage = _pesanErrorAuth(e.message);
      return false;
    } catch (e) {
      errorMessage = 'Registrasi gagal: $e';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() => _authService.logout();

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  String _pesanErrorAuth(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials')) return 'NIM/NIP atau kata sandi salah';
    if (m.contains('email not confirmed')) return 'Akun belum aktif';
    return 'Terjadi kesalahan: $message';
  }
}
