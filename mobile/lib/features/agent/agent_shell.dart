import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/dio_client.dart';
import '../../data/api/flights_api.dart';
import '../../state/flights_state.dart';
import '../admin/announcements_management_screen.dart';
import '../admin/stats_screen.dart';
import '../worker/notifications_screen.dart';
import '../worker/today_screen.dart';
import '../worker/week_screen.dart';
import 'flight_management_screen.dart';
import 'notification_compose_screen.dart';

/// Coque de l'agent du bureau de voyage.
///
/// Les actions sensibles (annulation, report, envoi de notification) exigent
/// une confirmation. L'agent ne peut pas créer d'administrateur : le backend
/// reste l'autorité en matière de permissions.
class AgentShell extends StatefulWidget {
  const AgentShell({super.key});

  @override
  State<AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends State<AgentShell> {
  int _index = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Chaque écran de type « liste de vols » dispose de son propre état de
    // filtres afin d'éviter toute interférence entre les onglets.
    final dio = context.read<DioClient>();
    _screens = [
      ChangeNotifierProvider<FlightsState>(
        create: (_) => FlightsState(FlightsApi(dio)),
        child: const TodayScreen(),
      ),
      const WeekScreen(),
      ChangeNotifierProvider<FlightsState>(
        create: (_) => FlightsState(FlightsApi(dio)),
        child: const FlightManagementScreen(),
      ),
      const AnnouncementsManagementScreen(canManage: true),
      const _AgentNotificationsScreen(),
      const StatsScreen(),
    ];
  }

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today),
      label: 'Aujourd\'hui',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_view_week_outlined),
      selectedIcon: Icon(Icons.calendar_view_week),
      label: 'Programme',
    ),
    NavigationDestination(
      icon: Icon(Icons.flight_outlined),
      selectedIcon: Icon(Icons.flight),
      label: 'Vols',
    ),
    NavigationDestination(
      icon: Icon(Icons.campaign_outlined),
      selectedIcon: Icon(Icons.campaign),
      label: 'Annonces',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'Notifications',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Stats',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: _destinations,
      ),
    );
  }
}

/// Boîte de réception des notifications avec accès à la composition.
class _AgentNotificationsScreen extends StatelessWidget {
  const _AgentNotificationsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const NotificationsScreen(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NotificationComposeScreen(),
          ),
        ),
        icon: const Icon(Icons.send),
        label: const Text('Envoyer'),
      ),
    );
  }
}
