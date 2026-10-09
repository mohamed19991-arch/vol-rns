import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'data/api/devices_api.dart';
import 'data/api/dio_client.dart';
import 'data/services/fcm_service.dart';
import 'data/services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Firebase encapsulée : si `android/app/google-services.json`
  // est absent, l'application démarre quand même (sans notifications push).
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (error) {
    debugPrint('Firebase non configuré (google-services.json manquant ?) : $error');
  }

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final sessionStore = SessionStore(secureStorage);
  final dioClient = DioClient(sessionStore);
  final devicesApi = DevicesApi(dioClient);
  final fcmService = FcmService(devicesApi);

  if (firebaseReady) {
    await fcmService.init();
  }

  runApp(
    VolRnsApp(
      dioClient: dioClient,
      sessionStore: sessionStore,
      fcmService: fcmService,
    ),
  );
}
