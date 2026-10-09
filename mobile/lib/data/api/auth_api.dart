import '../models/app_user.dart';
import 'dio_client.dart';

/// Resultat d'une connexion reussie.
class AuthResult {
  const AuthResult({
    required this.access,
    required this.refresh,
    required this.user,
  });

  final String access;
  final String refresh;
  final AppUser user;
}

/// Endpoints d'authentification et de profil (`/auth/*`, `/me/`).
class AuthApi extends BaseApi {
  AuthApi(super.client);

  Future<AuthResult> login({
    required String email,
    required String password,
  }) {
    return guard(() async {
      final response = await client.dio.post<Map<String, dynamic>>(
        '/auth/login/',
        data: {'email': email, 'password': password},
      );
      final data = response.data!;
      final tokens = data['tokens'] as Map<String, dynamic>;
      return AuthResult(
        access: tokens['access'] as String,
        refresh: tokens['refresh'] as String,
        user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
      );
    });
  }

  Future<void> logout(String refresh) {
    return guard(() async {
      await client.dio.post('/auth/logout/', data: {'refresh': refresh});
    });
  }

  Future<void> requestPasswordReset(String email) {
    return guard(() async {
      await client.dio.post('/auth/password-reset/', data: {'email': email});
    });
  }

  Future<void> confirmPasswordReset({
    required String uid,
    required String token,
    required String newPassword,
  }) {
    return guard(() async {
      await client.dio.post('/auth/password-reset/confirm/', data: {
        'uid': uid,
        'token': token,
        'new_password': newPassword,
      });
    });
  }

  Future<AppUser> me() {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>('/me/');
      return AppUser.fromJson(response.data!);
    });
  }

  Future<AppUser> updateMe(Map<String, dynamic> payload) {
    return guard(() async {
      final response =
          await client.dio.patch<Map<String, dynamic>>('/me/', data: payload);
      return AppUser.fromJson(response.data!);
    });
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return guard(() async {
      await client.dio.post('/me/change-password/', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
    });
  }
}
