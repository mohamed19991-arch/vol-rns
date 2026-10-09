import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'data/api/dio_client.dart';
import 'data/api/flights_api.dart';
import 'data/api/notifications_api.dart';
import 'data/services/fcm_service.dart';
import 'data/services/session_store.dart';
import 'features/admin/admin_shell.dart';
import 'features/agent/agent_shell.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/worker/worker_shell.dart';
import 'state/auth_state.dart';
import 'state/flights_state.dart';
import 'state/notifications_state.dart';

/// Racine de l'application : providers + MaterialApp + navigation par rôle.
class VolRnsApp extends StatelessWidget {
  const VolRnsApp({
    super.key,
    required this.dioClient,
    required this.sessionStore,
    required this.fcmService,
  });

  final DioClient dioClient;
  final SessionStore sessionStore;
  final FcmService fcmService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DioClient>.value(value: dioClient),
        Provider<SessionStore>.value(value: sessionStore),
        Provider<FcmService>.value(value: fcmService),
        ChangeNotifierProvider<AuthState>(
          create: (_) => AuthState(
            dioClient: dioClient,
            sessionStore: sessionStore,
            fcmService: fcmService,
          )..restoreSession(),
        ),
        ChangeNotifierProvider<FlightsState>(
          create: (_) => FlightsState(FlightsApi(dioClient)),
        ),
        ChangeNotifierProvider<NotificationsState>(
          create: (_) => NotificationsState(NotificationsApi(dioClient)),
        ),
      ],
      child: MaterialApp(
        title: 'VOL-RNS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _RootRouter(),
        routes: {
          LoginScreen.routeName: (_) => const LoginScreen(),
          ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
        },
      ),
    );
  }
}

/// Affiche un écran selon l'état d'authentification et le rôle renvoyé
/// par le backend.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (auth.initializing) {
      return const _SplashScreen();
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    switch (auth.role) {
      case AppConstants.roleAdmin:
        return const AdminShell();
      case AppConstants.roleAgent:
        return const AgentShell();
      case AppConstants.roleWorker:
      default:
        return const WorkerShell();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.flight_takeoff, size: 72, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'VOL-RNS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Gestion hebdomadaire des vols',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
