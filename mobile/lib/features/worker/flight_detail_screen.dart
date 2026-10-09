import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/api/dio_client.dart';
import '../../data/api/favorites_api.dart';
import '../../data/api/flights_api.dart';
import '../../data/models/change_log.dart';
import '../../data/models/flight.dart';
import '../../state/auth_state.dart';
import '../agent/flight_actions_sheet.dart';
import '../agent/flight_form_screen.dart';

/// Détail d'un vol : informations complètes, historique et action favori.
class FlightDetailScreen extends StatefulWidget {
  const FlightDetailScreen({super.key, required this.flightId, this.initialFlight});

  final int flightId;
  final Flight? initialFlight;

  @override
  State<FlightDetailScreen> createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  Flight? _flight;
  List<ChangeLog> _history = [];
  bool _loading = true;
  String? _error;
  bool _favoriteLoading = false;

  @override
  void initState() {
    super.initState();
    _flight = widget.initialFlight;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = FlightsApi(context.read<DioClient>());
      final results = await Future.wait([
        api.detail(widget.flightId),
        api.history(widget.flightId),
      ]);
      _flight = results[0] as Flight;
      _history = results[1] as List<ChangeLog>;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addFavorite() async {
    final flight = _flight;
    if (flight == null) return;
    setState(() => _favoriteLoading = true);
    try {
      final api = FavoritesApi(context.read<DioClient>());
      await api.create({
        'favorite_type': 'flight',
        'flight': flight.id,
        'notifications_enabled': true,
      });
      _showMessage('Vol ajouté aux favoris.', success: true);
    } on ApiException catch (error) {
      // Déduplication : le backend renvoie « Ce favori existe deja ».
      final message = (error.firstFieldError() ?? error.message).toLowerCase();
      if (error.statusCode == 400 && message.contains('existe')) {
        _showMessage('Ce vol figure déjà dans vos favoris.');
      } else {
        _showMessage(error.firstFieldError() ?? error.message);
      }
    } finally {
      if (mounted) setState(() => _favoriteLoading = false);
    }
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _openActions() async {
    final flight = _flight;
    if (flight == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FlightActionsSheet(flight: flight),
    );
    if (updated == true) {
      await _load();
    }
  }

  Future<void> _openEdit() async {
    final flight = _flight;
    if (flight == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FlightFormScreen(flight: flight)),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = context.watch<AuthState>().user?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du vol'),
        actions: [
          if (canManage && _flight != null)
            IconButton(
              tooltip: 'Actions',
              icon: const Icon(Icons.more_vert),
              onPressed: _openActions,
            ),
          if (canManage && _flight != null)
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEdit,
            ),
          IconButton(
            tooltip: 'Ajouter aux favoris',
            icon: _favoriteLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.star_border),
            onPressed: _favoriteLoading ? null : _addFavorite,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _flight == null) {
      return const LoadingView(message: 'Chargement du vol...');
    }
    if (_error != null && _flight == null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    final flight = _flight;
    if (flight == null) {
      return const ErrorView(message: 'Vol introuvable.');
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${flight.originDetail?.code ?? ''} → '
                  '${flight.destinationDetail?.code ?? ''}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              StatusBadge(status: flight.status, label: flight.statusLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            flight.flightCode.isEmpty ? 'Vol' : flight.flightCode,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            children: [
              _InfoRow(label: 'Date', value: Formatters.formatDate(flight.flightDate)),
              _InfoRow(label: 'Jour', value: flight.dayLabel),
              _InfoRow(
                label: 'Trajet',
                value: '${flight.originDetail?.name ?? ''} '
                    '(${flight.originDetail?.code ?? ''}) → '
                    '${flight.destinationDetail?.name ?? ''} '
                    '(${flight.destinationDetail?.code ?? ''})',
              ),
              _InfoRow(
                label: 'Enregistrement',
                value: Formatters.formatTime(flight.registrationTime),
                previous: flight.previousRegistrationTime,
              ),
              _InfoRow(
                label: 'Décollage',
                value: Formatters.formatTime(flight.departureTime),
                previous: flight.previousDepartureTime,
              ),
              _InfoRow(
                label: 'Arrivée',
                value: Formatters.formatTime(flight.arrivalTime),
                previous: flight.previousArrivalTime,
              ),
              _InfoRow(
                label: 'Vol exceptionnel',
                value: flight.isExceptional ? 'Oui' : 'Non',
              ),
            ],
          ),
          if (flight.observation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Observation',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(flight.observation),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Historique',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucune modification enregistrée.'),
            )
          else
            for (final log in _history) _HistoryTile(log: log),
          if (flight.updatedByEmail.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Dernière modification par ${flight.updatedByEmail}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.previous,
  });

  final String label;
  final String value;
  final String? previous;

  @override
  Widget build(BuildContext context) {
    final prev = previous == null ? '' : Formatters.formatTime(previous);
    final showPrevious = prev.isNotEmpty && prev != value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: value.isEmpty ? '—' : value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (showPrevious)
                    TextSpan(
                      text: '  (avant : $prev)',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.log});

  final ChangeLog log;

  @override
  Widget build(BuildContext context) {
    final field = AppConstants.labelFromMap(AppConstants.fieldLabels, log.fieldName);
    final title = log.changeTypeLabel.isNotEmpty
        ? log.changeTypeLabel
        : AppConstants.labelFromMap(AppConstants.changeTypeLabels, log.changeType);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.history, size: 20),
        title: Text(field.isEmpty ? title : '$title — $field'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (log.oldValue.isNotEmpty || log.newValue.isNotEmpty)
              Text('${log.oldValue} → ${log.newValue}'),
            if (log.note.isNotEmpty) Text(log.note),
            Text(
              '${Formatters.formatDateTime(log.createdAt)}'
              '${log.changedByEmail.isEmpty ? '' : ' • ${log.changedByEmail}'}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
