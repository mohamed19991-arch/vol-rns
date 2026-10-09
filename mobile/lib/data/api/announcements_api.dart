import '../models/announcement.dart';
import '../models/paged_result.dart';
import 'dio_client.dart';

/// Annonces générales ou ciblées.
class AnnouncementsApi extends BaseApi {
  AnnouncementsApi(super.client);

  Future<PagedResult<Announcement>> list({
    String? search,
    String? status,
    String? category,
    String? priority,
    String? targetType,
    String? ordering,
    int page = 1,
    int pageSize = 20,
  }) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/announcements/',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (status != null && status.isNotEmpty) 'status': status,
          if (category != null && category.isNotEmpty) 'category': category,
          if (priority != null && priority.isNotEmpty) 'priority': priority,
          if (targetType != null && targetType.isNotEmpty) 'target_type': targetType,
          if (ordering != null && ordering.isNotEmpty) 'ordering': ordering,
          'page': page,
          'page_size': pageSize,
        },
      );
      return PagedResult.fromJson(response.data!, Announcement.fromJson);
    });
  }

  Future<Announcement> create(Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/announcements/', data: payload);
      return Announcement.fromJson(response.data!);
    });
  }

  Future<Announcement> update(int id, Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .patch<Map<String, dynamic>>('/announcements/$id/', data: payload);
      return Announcement.fromJson(response.data!);
    });
  }

  Future<void> delete(int id) {
    return guard(() async {
      await client.dio.delete('/announcements/$id/');
    });
  }

  Future<Announcement> publish(int id) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/announcements/$id/publish/');
      return Announcement.fromJson(response.data!);
    });
  }

  Future<Announcement> unpublish(int id) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/announcements/$id/unpublish/');
      return Announcement.fromJson(response.data!);
    });
  }
}
