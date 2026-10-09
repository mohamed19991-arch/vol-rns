import '../models/destination.dart';
import '../models/paged_result.dart';
import 'dio_client.dart';

/// Gestion des destinations.
class DestinationsApi extends BaseApi {
  DestinationsApi(super.client);

  Future<PagedResult<Destination>> list({
    String? search,
    bool? isActive,
    int page = 1,
    int pageSize = 100,
  }) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/destinations/',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (isActive != null) 'is_active': isActive,
          'page': page,
          'page_size': pageSize,
        },
      );
      return PagedResult.fromJson(response.data!, Destination.fromJson);
    });
  }

  /// Recupere TOUTES les destinations (parcourt les pages).
  Future<List<Destination>> listAll({bool? isActive}) async {
    final all = <Destination>[];
    var page = 1;
    while (true) {
      final result = await list(isActive: isActive, page: page, pageSize: 100);
      all.addAll(result.results);
      if (result.next == null || !result.hasMore) break;
      page += 1;
      if (page > 50) break; // garde-fou
    }
    return all;
  }

  Future<Destination> create(Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/destinations/', data: payload);
      return Destination.fromJson(response.data!);
    });
  }

  Future<Destination> update(int id, Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .patch<Map<String, dynamic>>('/destinations/$id/', data: payload);
      return Destination.fromJson(response.data!);
    });
  }

  Future<void> delete(int id) {
    return guard(() async {
      await client.dio.delete('/destinations/$id/');
    });
  }
}
