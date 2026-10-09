import '../models/favorite.dart';
import '../models/paged_result.dart';
import 'dio_client.dart';

/// Favoris du travailleur connecte.
class FavoritesApi extends BaseApi {
  FavoritesApi(super.client);

  Future<PagedResult<Favorite>> list({int page = 1, int pageSize = 100}) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/favorites/',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      return PagedResult.fromJson(response.data!, Favorite.fromJson);
    });
  }

  /// Cree un favori. Lance une [ApiException] avec un message francais si le
  /// favori existe deja (HTTP 400 « Ce favori existe deja »).
  Future<Favorite> create(Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/favorites/', data: payload);
      return Favorite.fromJson(response.data!);
    });
  }

  Future<void> delete(int id) {
    return guard(() async {
      await client.dio.delete('/favorites/$id/');
    });
  }

  Future<Favorite> toggleNotifications(int id) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/favorites/$id/toggle_notifications/');
      return Favorite.fromJson(response.data!);
    });
  }
}
