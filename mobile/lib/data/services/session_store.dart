import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';

/// Stockage securise des jetons d'authentification et de l'utilisateur courant.
///
/// Les jetons sont conserves dans le keystore Android (chiffres). Aucun secret
/// serveur (cle PostgreSQL, Firebase Admin...) n'est jamais stocke côté client.
class SessionStore {
  SessionStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String _kAccess = 'volrns_access_token';
  static const String _kRefresh = 'volrns_refresh_token';
  static const String _kUser = 'volrns_user';

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> saveAccessToken(String access) async {
    await _storage.write(key: _kAccess, value: access);
  }

  Future<String?> get accessToken => _storage.read(key: _kAccess);

  Future<String?> get refreshToken => _storage.read(key: _kRefresh);

  Future<void> saveUser(AppUser user) async {
    await _storage.write(key: _kUser, value: jsonEncode(user.toJson()));
  }

  Future<AppUser?> getUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}
