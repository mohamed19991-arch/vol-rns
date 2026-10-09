import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../data/api/auth_api.dart';
import '../data/api/dio_client.dart';
import '../data/models/app_user.dart';
import '../data/services/fcm_service.dart';
import '../data/services/session_store.dart';

/// Etat d'authentification de l'application.
///
/// Le rôle provient exclusivement du backend (réponse de connexion ou `/me/`).
class AuthState extends ChangeNotifier {
  AuthState({
    required DioClient dioClient,
    required SessionStore sessionStore,
    required FcmService fcmService,
  })  : _authApi = AuthApi(dioClient),
        _session = sessionStore,
        _fcm = fcmService {
    dioClient.onSessionExpired = _onSessionExpired;
    _fcm.onNotificationReceived = () => notifyListeners();
  }

  final AuthApi _authApi;
  final SessionStore _session;
  final FcmService _fcm;

  AppUser? _user;
  bool _initializing = true;
  bool _busy = false;

  AppUser? get user => _user;
  bool get initializing => _initializing;
  bool get busy => _busy;
  bool get isAuthenticated => _user != null;
  String? get role => _user?.role;
  String get displayName => _user?.fullName ?? '';

  /// Restaure la session au démarrage (jetons + utilisateur en cache).
  Future<void> restoreSession() async {
    try {
      final token = await _session.accessToken;
      final cachedUser = await _session.getUser();
      if (token != null && token.isNotEmpty && cachedUser != null) {
        _user = cachedUser;
        notifyListeners();
        // Rafraîchit le profil en arrière-plan (sans bloquer l'affichage).
        try {
          final fresh = await _authApi.me();
          _user = fresh;
          await _session.saveUser(fresh);
          notifyListeners();
        } on ApiException {
          // Ignoré : on conserve l'utilisateur en cache.
        }
        await _fcm.registerToken();
      }
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final result = await _authApi.login(email: email, password: password);
      await _session.saveTokens(
        access: result.access,
        refresh: result.refresh,
      );
      await _session.saveUser(result.user);
      _user = result.user;
      await _fcm.registerToken();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final refresh = await _session.refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _authApi.logout(refresh);
      } catch (_) {
        // La déconnexion locale doit réussir même si l'appel échoue.
      }
    }
    await _fcm.unregisterToken();
    await _session.clear();
    _user = null;
    notifyListeners();
  }

  /// Met à jour le profil (/me/) puis rafraîchit l'utilisateur courant.
  Future<AppUser> updateProfile(Map<String, dynamic> payload) async {
    _busy = true;
    notifyListeners();
    try {
      final updated = await _authApi.updateMe(payload);
      _user = updated;
      await _session.saveUser(updated);
      return updated;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _authApi.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  Future<void> refreshUser() async {
    final fresh = await _authApi.me();
    _user = fresh;
    await _session.saveUser(fresh);
    notifyListeners();
  }

  void _onSessionExpired() {
    // Déclenché par DioClient lorsque le rafraîchissement échoue.
    Future.microtask(() async {
      await _session.clear();
      _user = null;
      notifyListeners();
    });
  }
}
