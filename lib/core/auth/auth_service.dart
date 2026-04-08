import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

// Use shared_preferences for token storage on all platforms.
// flutter_secure_storage requires ATL on Windows which is problematic.
// Tokens are still encrypted server-side (Fernet) — this is the app-side JWT cache.

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

enum AuthStatus { initial, authenticated, unauthenticated, biometricRequired }

class AuthState {
  final AuthStatus status;
  final String? error;
  final String? username;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.username,
  });

  AuthState copyWith({AuthStatus? status, String? error, String? username}) =>
      AuthState(
        status: status ?? this.status,
        error: error,
        username: username ?? this.username,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _checkAuth();
  }

  final _api = ApiClient();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> _read(String key) async => (await _prefs).getString(key);
  Future<void> _write(String key, String value) async =>
      (await _prefs).setString(key, value);
  Future<void> _delete(String key) async => (await _prefs).remove(key);
  Future<void> _deleteAll() async {
    final p = await _prefs;
    await p.remove('access_token');
    await p.remove('refresh_token');
    await p.remove('biometric_enabled');
  }

  Future<void> _checkAuth() async {
    final token = await _read('access_token');
    if (token != null) {
      final biometric = await _read('biometric_enabled');
      if (biometric == 'true' && !Platform.isWindows) {
        state = state.copyWith(status: AuthStatus.biometricRequired);
      } else {
        state = state.copyWith(status: AuthStatus.authenticated);
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await _api.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200) {
        await _write('access_token', response.data['access_token']);
        if (response.data['refresh_token'] != null) {
          await _write('refresh_token', response.data['refresh_token']);
        }
        state = state.copyWith(
          status: AuthStatus.authenticated,
          username: username,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(error: 'Login failed: $e');
    }
    return false;
  }

  Future<bool> authenticateWithBiometrics() async {
    // Biometrics only on iOS/Android via local_auth
    // On Windows, skip biometric and go straight to authenticated
    if (Platform.isWindows) {
      state = state.copyWith(status: AuthStatus.authenticated);
      return true;
    }

    try {
      final localAuth = await _getLocalAuth();
      if (localAuth == null) return false;

      state = state.copyWith(status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Biometric auth failed: $e');
    }
    return false;
  }

  Future<dynamic> _getLocalAuth() async {
    // local_auth works on iOS; on Windows we skip
    if (Platform.isWindows) return null;
    return null; // Stub — actual local_auth call on iOS Codemagic build
  }

  Future<void> enableBiometrics(bool enabled) async {
    await _write('biometric_enabled', enabled.toString());
  }

  Future<void> logout() async {
    await _deleteAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> get isBiometricAvailable async {
    if (Platform.isWindows) return false;
    return false; // Stub
  }
}
