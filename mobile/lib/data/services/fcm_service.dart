import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/devices_api.dart';

/// Service de notifications : canal local (avec son) et Firebase Cloud Messaging.
///
/// Deux etapes independantes :
///   * [init]     : configuration locale (canal Android + autorisation). Ne
///                  depend PAS de Firebase : l'utilisateur est invite a
///                  autoriser les notifications des le premier lancement ;
///   * [initPush] : recuperation du jeton FCM. Sans `google-services.json`,
///                  Firebase n'est pas configure et cette etape est ignoree.
///
/// Aucune cle privee Firebase n'est embarquee dans l'application.
class FcmService {
  FcmService(this._devicesApi);

  final DevicesApi _devicesApi;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'vol_rns_default';
  static const String _channelName = 'Notifications VOL-RNS';
  static const String _channelDescription = 'Alertes de vols et annonces';
  static const String _deviceIdKey = 'volrns_device_id';

  /// Canal Android partage avec le backend : importance haute + son.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  bool _localReady = false;
  bool _pushReady = false;

  /// Vrai si les notifications locales sont pretes.
  bool get isInitialized => _localReady;

  /// Vrai si l'envoi/reception push (Firebase) est operationnel.
  bool get isPushReady => _pushReady;

  /// Notifie l'interface qu'une notification a ete recue (rafraichir la boite).
  VoidCallback? onNotificationReceived;

  /// Configure le canal local et demande l'autorisation. Ne leve jamais
  /// d'exception : l'application doit demarrer meme si Firebase est absent.
  Future<void> init() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _local.initialize(initSettings);

      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Le canal doit exister AVANT la premiere notification pour que le son
      // soit applique (sinon Android utilise un canal de repli).
      await android?.createNotificationChannel(_channel);
      // Android 13+ : affiche la demande d'autorisation a l'utilisateur.
      await android?.requestNotificationsPermission();

      _localReady = true;
    } catch (error) {
      debugPrint('Notifications locales indisponibles : $error');
      _localReady = false;
    }
  }

  /// Initialise Firebase Cloud Messaging. A n'appeler que si Firebase est pret.
  Future<void> initPush() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      messaging.onTokenRefresh.listen(_registerToken);

      _pushReady = true;
    } catch (error) {
      debugPrint('FCM non initialise : $error');
      _pushReady = false;
    }
  }

  /// Recupere le jeton courant et l'enregistre aupres du backend.
  Future<void> registerToken() async {
    if (!_pushReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (error) {
      debugPrint('Enregistrement du jeton FCM impossible : $error');
    }
  }

  /// Desenregistre le jeton (a la deconnexion).
  Future<void> unregisterToken() async {
    if (!_pushReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _devicesApi.unregister(token);
      }
    } catch (error) {
      debugPrint('Desenregistrement du jeton FCM impossible : $error');
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
    final title = notification?.title ??
        (message.data['title'] as String?) ??
        'Notification';
    final body = notification?.body ?? (message.data['body'] as String?) ?? '';
    await _showLocal(title, body);
    onNotificationReceived?.call();
  }

  Future<void> _showLocal(String title, String body) async {
    if (!_localReady) return;
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    await _local.show(
      Random().nextInt(1 << 31),
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Identifiant d'appareil stable, genere une seule fois.
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
