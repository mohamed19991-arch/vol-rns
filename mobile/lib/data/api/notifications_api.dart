import '../models/app_notification.dart';
import '../models/paged_result.dart';
import 'dio_client.dart';

/// Boite de reception des notifications et gestion (envoi) côté agent.
class NotificationsApi extends BaseApi {
  NotificationsApi(super.client);

  Future<PagedResult<AppNotification>> inbox({
    int page = 1,
    int pageSize = 20,
  }) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/notifications/',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      return PagedResult.fromJson(response.data!, AppNotification.fromJson);
    });
  }

  Future<int> unreadCount() {
    return guard(() async {
      final response = await client.dio
          .get<Map<String, dynamic>>('/notifications/unread_count/');
      return (response.data?['unread'] as num?)?.toInt() ?? 0;
    });
  }

  Future<void> markRead(int id) {
    return guard(() async {
      await client.dio.post('/notifications/$id/mark_read/');
    });
  }

  Future<void> markAllRead() {
    return guard(() async {
      await client.dio.post('/notifications/mark_all_read/');
    });
  }

  // --- Gestion (agent / administrateur) --------------------------------

  Future<PagedResult<AppNotification>> managementList({
    int page = 1,
    int pageSize = 20,
  }) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/notification-management/',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      return PagedResult.fromJson(response.data!, AppNotification.fromJson);
    });
  }

  Future<AppNotification> send(Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/notification-management/', data: payload);
      return AppNotification.fromJson(response.data!);
    });
  }

  Future<List<Map<String, dynamic>>> recipients(int id) {
    return guard(() async {
      final response = await client.dio
          .get<List<dynamic>>('/notification-management/$id/recipients/');
      return (response.data ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    });
  }

  Future<Map<String, dynamic>> resend(int id) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/notification-management/$id/resend/');
      return response.data ?? {};
    });
  }
}
