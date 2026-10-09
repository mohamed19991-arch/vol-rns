import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import 'announcements_management_screen.dart';
import 'audit_logs_screen.dart';
import 'destinations_screen.dart';
import 'flights_management_screen.dart';
import 'schedule_management_screen.dart';
import 'stats_screen.dart';
import 'users_screen.dart';

/// Coque de l'administrateur : tableau de bord + tiroir de navigation.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  static const List<_AdminSection> _sections = [
    _AdminSection(
      'Utilisateurs',
      Icons.people_outline,
      UsersScreen(),
      'Créer, modifier et désactiver les comptes et attribuer les rôles.',
    ),
    _AdminSection(
      'Destinations',
      Icons.place_outlined,
      DestinationsScreen(),
      'Référentiel des villes et aéroports desservis.',
    ),
    _AdminSection(
      'Programme',
      Icons.calendar_view_week_outlined,
      ScheduleManagementScreen(),
      'Programme hebdomadaire et génération des vols datés.',
    ),
    _AdminSection(
      'Vols',
      Icons.flight_outlined,
      FlightsManagementScreen(),
      'Consulter, modifier et supprimer les vols.',
    ),
    _AdminSection(
      'Annonces',
      Icons.campaign_outlined,
      AnnouncementsManagementScreen(),
      'Créer, publier et dépublier les annonces.',
    ),
    _AdminSection(
      'Statistiques',
      Icons.bar_chart_outlined,
      StatsScreen(),
      'Indicateurs sur les vols par statut et par destination.',
    ),
    _AdminSection(
      'Historique',
      Icons.history,
      AuditLogsScreen(),
      'Journal des actions réalisées dans l\'application.',
    ),
  ];

  void _open(BuildContext context, _AdminSection section) {
    Navigator.of(context).pop(); // ferme le tiroir
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => section.screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user?.fullName ?? ''),
                accountEmail: Text(user?.email ?? ''),
                currentAccountPicture: const CircleAvatar(
                  child: Icon(Icons.admin_panel_settings, size: 32),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final section in _sections)
                      ListTile(
                        leading: Icon(section.icon),
                        title: Text(section.title),
                        onTap: () => _open(context, section),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue, ${user?.fullName ?? ''}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Espace d\'administration VOL-RNS.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final section in _sections)
            Card(
              child: ListTile(
                leading: Icon(section.icon,
                    color: Theme.of(context).colorScheme.primary),
                title: Text(section.title),
                subtitle: Text(section.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => section.screen),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminSection {
  const _AdminSection(this.title, this.icon, this.screen, this.description);

  final String title;
  final IconData icon;
  final Widget screen;
  final String description;
}
