import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../core/repositories/user_repository.dart';
import '../core/services/auth_service.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, UserRepository? userRepository})
      : _authService = authService ?? AuthService(),
        _userRepository = userRepository ?? UserRepository() {
    _authService.authStateChanges.listen(_onAuthChanged);
  }

  final AuthService _authService;
  final UserRepository _userRepository;

  AuthStatus status = AuthStatus.unknown;
  UserModel? currentUser;
  String? errorMessage;
  bool isBusy = false;

  Future<void> _onAuthChanged(fb.User? user) async {
    if (user == null) {
      status = AuthStatus.loggedOut;
      currentUser = null;
      notifyListeners();
      return;
    }
    try {
      currentUser = await _userRepository.getUser(user.uid);
      status = currentUser != null ? AuthStatus.loggedIn : AuthStatus.loggedOut;
    } catch (_) {
      status = AuthStatus.loggedOut;
    }
    notifyListeners();
  }

  Future<bool> login({required String nim, required String password}) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      currentUser = await _authService.login(nim: nim, password: password);
      status = AuthStatus.loggedIn;
      return true;
    } on fb.FirebaseAuthException catch (e) {
      errorMessage = _pesanError(e.code);
      return false;
    } catch (e) {
      errorMessage = 'Login gagal: $e';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String nim,
    required String nama,
    required String password,
    required UserRole role,
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      currentUser = await _authService.register(nim: nim, nama: nama, password: password, role: role);
      status = AuthStatus.loggedIn;
      return true;
    } on fb.FirebaseAuthException catch (e) {
      errorMessage = _pesanError(e.code);
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

  String _pesanError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'NIM/NIP belum terdaftar';
      case 'wrong-password':
      case 'invalid-credential':
        return 'NIM atau kata sandi salah';
      case 'email-already-in-use':
        return 'NIM sudah terdaftar, silakan login';
      case 'weak-password':
        return 'Kata sandi minimal 6 karakter';
      default:
        return 'Terjadi kesalahan ($code)';
    }
  }
}
