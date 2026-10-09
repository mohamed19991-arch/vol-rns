import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/devices_api.dart';

/// Service de gestion des notifications push (Firebase Cloud Messaging).
///
/// Toute erreur d'initialisation est absorbée : l'application doit démarrer
/// même si `android/app/google-services.json` est absent (Firebase non
/// configuré). Aucune clé privée n'est embarquée dans l'application.
class FcmService {
  FcmService(this._devicesApi);

  final DevicesApi _devicesApi;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Notifie l'interface qu'une notification a été reçue (rafraîchir la boîte).
  VoidCallback? onNotificationReceived;

  static const String _channelId = 'vol_rns_default';
  static const String _deviceIdKey = 'volrns_device_id';

  /// Initialise FCM et les notifications locales. Silencieux en cas d'échec.
  Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _local.initialize(initSettings);

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      messaging.onTokenRefresh.listen((token) {
        _registerToken(token);
      });

      _initialized = true;
    } catch (error) {
      // Firebase non configuré : on continue sans push.
      debugPrint('FCM non initialisé : $error');
      _initialized = false;
    }
  }

  /// Récupère le jeton courant et l'enregistre auprès du backend.
  Future<void> registerToken() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (error) {
      debugPrint('Enregistrement du jeton FCM impossible : $error');
    }
  }

  /// Désenregistre le jeton (à la déconnexion).
  Future<void> unregisterToken() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _devicesApi.unregister(token);
      }
    } catch (error) {
      debugPrint('Désenregistrement du jeton FCM impossible : $error');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final deviceId = await _deviceId();
      await _devicesApi.register(token: token, deviceId: deviceId);
    } catch (error) {
      debugPrint('Jeton FCM non transmis au backend : $error');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ?? (message.data['title'] as String?) ?? 'Notification';
    final body =
        notification?.body ?? (message.data['body'] as String?) ?? '';
    await _showLocal(title, body);
    onNotificationReceived?.call();
  }

  Future<void> _showLocal(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Notifications VOL-RNS',
      channelDescription: 'Alertes de vols et annonces',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _local.show(
      Random().nextInt(1 << 31),
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Identifiant d'appareil stable, généré une seule fois.
  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = 'android-${DateTime.now().millisecondsSinceEpoch}-'
        '${Random().nextInt(1 << 20)}';
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }
}
