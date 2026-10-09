import '../models/app_user.dart';
import '../models/paged_result.dart';
import 'dio_client.dart';

/// Gestion des utilisateurs (administrateur uniquement côté backend).
class UsersApi extends BaseApi {
  UsersApi(super.client);

  Future<PagedResult<AppUser>> list({
    String? role,
    bool? isActive,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/users/',
        queryParameters: {
          if (role != null) 'role': role,
          if (isActive != null) 'is_active': isActive,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
          'page_size': pageSize,
        },
      );
      return PagedResult.fromJson(response.data!, AppUser.fromJson);
    });
  }

  Future<AppUser> get(int id) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>('/users/$id/');
      return AppUser.fromJson(response.data!);
    });
  }

  Future<AppUser> create(Map<String, dynamic> payload) {
    return guard(() async {
      final response =
          await client.dio.post<Map<String, dynamic>>('/users/', data: payload);
      return AppUser.fromJson(response.data!);
    });
  }

  Future<AppUser> update(int id, Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .patch<Map<String, dynamic>>('/users/$id/', data: payload);
      return AppUser.fromJson(response.data!);
    });
  }

  Future<void> delete(int id) {
    return guard(() async {
      await client.dio.delete('/users/$id/');
    });
  }

  Future<void> setPassword(int id, String password) {
    return guard(() async {
      await client.dio.post('/users/$id/set_password/', data: {
        'password': password,
      });
    });
  }
}
