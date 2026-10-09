import 'dio_client.dart';

/// Enregistrement des jetons FCM de l'appareil.
class DevicesApi extends BaseApi {
  DevicesApi(super.client);

  /// Enregistre (ou met a jour) le jeton de l'appareil auprès du backend.
  Future<void> register({
    required String token,
    required String deviceId,
    String platform = 'android',
  }) {
    return guard(() async {
      await client.dio.post('/devices/', data: {
        'token': token,
        'platform': platform,
        'device_id': deviceId,
      });
    });
  }

  Future<void> delete(int id) {
    return guard(() async {
      await client.dio.delete('/devices/$id/');
    });
  }

  Future<void> unregister(String token) {
    return guard(() async {
      await client.dio.post('/devices/unregister/', data: {'token': token});
    });
  }
}
