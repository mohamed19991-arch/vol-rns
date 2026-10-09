import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/flight_card.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api/announcements_api.dart';
import '../../data/api/dio_client.dart';
import '../../data/models/announcement.dart';
import '../../data/models/flight.dart';
import '../../state/auth_state.dart';
import '../../state/flights_state.dart';
import '../../state/notifications_state.dart';
import 'announcements_screen.dart';
import 'flight_detail_screen.dart';
import 'notifications_screen.dart';

/// Accueil du travailleur : vols du jour, prochains vols, perturbations
/// et annonces importantes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Announcement> _announcements = [];
  bool _loadingAnnouncements = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final flights = context.read<FlightsState>();
    final notifications = context.read<NotificationsState>();
    await Future.wait([
      flights.loadToday(),
      flights.loadUpcoming(),
      notifications.refreshUnread(),
      _loadAnnouncements(),
    ]);
  }

  Future<void> _loadAnnouncements() async {
    if (mounted) setState(() => _loadingAnnouncements = true);
    try {
      final api = AnnouncementsApi(context.read<DioClient>());
      final result = await api.list(ordering: '-published_at', pageSize: 5);
      _announcements = result.results;
    } on ApiException {
      _announcements = [];
    } finally {
      if (mounted) setState(() => _loadingAnnouncements = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final flights = context.watch<FlightsState>();
    final notifications = context.watch<NotificationsState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, ${auth.user?.firstName ?? ''}'.trim()),
        actions: [
          IconButton(
            tooltip: 'Annonces',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: notifications.unreadCount > 0,
              label: Text('${notifications.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _sectionTitle(context, 'Vols du jour'),
            _buildFlightSection(
              loading: flights.loadingToday,
              error: flights.todayError,
              onRetry: flights.loadToday,
              flights: flights.todayFlights,
              emptyMessage: "Aucun vol prévu aujourd'hui.",
            ),
            _sectionTitle(context, 'Prochains vols'),
            _buildFlightSection(
              loading: flights.loadingUpcoming,
              error: flights.upcomingError,
              onRetry: flights.loadUpcoming,
              flights: flights.upcomingFlights,
              emptyMessage: 'Aucun vol à venir.',
            ),
            _sectionTitle(context, 'Retards et annulations'),
            _buildDisruptions(context, flights.todayFlights),
            _sectionTitle(context, 'Annonces importantes'),
            _buildAnnouncements(context),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFlightSection({
    required bool loading,
    required String? error,
    required Future<void> Function() onRetry,
    required List<Flight> flights,
    required String emptyMessage,
  }) {
    if (loading && flights.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: LoadingView(),
      );
    }
    if (error != null && flights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorView(message: error, onRetry: onRetry),
      );
    }
    if (flights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: EmptyState(message: emptyMessage, icon: Icons.flight_outlined),
      );
    }
    final visible = flights.take(3).toList();
    return Column(
      children: [
        for (final flight in visible)
          FlightCard(
            flight: flight,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FlightDetailScreen(flightId: flight.id),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDisruptions(BuildContext context, List<Flight> flights) {
    final disrupted = flights.where((f) {
      return f.status == AppConstants.statusDelayed ||
          f.status == AppConstants.statusCancelled ||
          f.status == AppConstants.statusPostponed ||
          f.status == AppConstants.statusRescheduled;
    }).toList();

    if (disrupted.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: EmptyState(
          message: 'Aucune perturbation signalée.',
          icon: Icons.check_circle_outline,
        ),
      );
    }

    return Column(
      children: [
        for (final flight in disrupted)
          FlightCard(
            flight: flight,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FlightDetailScreen(flightId: flight.id),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnnouncements(BuildContext context) {
    if (_loadingAnnouncements) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: LoadingView(),
      );
    }
    final important = _announcements
        .where((a) => a.priority == 'high' || a.priority == 'urgent')
        .toList();
    final list = important.isNotEmpty ? important : _announcements;
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: EmptyState(message: 'Aucune annonce.', icon: Icons.campaign_outlined),
      );
    }
    return Column(
      children: [
        for (final announcement in list.take(3))
          Card(
            child: ListTile(
              leading: Icon(
                announcement.priority == 'urgent'
                    ? Icons.warning_amber_rounded
                    : Icons.campaign_outlined,
                color: announcement.priority == 'urgent'
                    ? Colors.red
                    : Colors.orange.shade800,
              ),
              title: Text(announcement.title),
              subtitle: Text(
                announcement.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
              ),
            ),
          ),
      ],
    );
  }
}
