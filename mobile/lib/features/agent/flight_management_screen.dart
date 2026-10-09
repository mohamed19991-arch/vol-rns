import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/flight_card.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api/destinations_api.dart';
import '../../data/api/dio_client.dart';
import '../../data/api/flights_api.dart';
import '../../data/models/destination.dart';
import '../../data/models/flight.dart';
import '../../state/flights_state.dart';
import '../worker/flight_detail_screen.dart';
import 'flight_actions_sheet.dart';
import 'flight_form_screen.dart';

/// Gestion des vols (agent) : filtres date / destination / statut / jour,
/// création, modification et actions métier.
class FlightManagementScreen extends StatefulWidget {
  const FlightManagementScreen({super.key, this.allowDelete = false});

  /// Réservé à l'administrateur : suppression logique d'un vol.
  final bool allowDelete;

  @override
  State<FlightManagementScreen> createState() => _FlightManagementScreenState();
}

class _FlightManagementScreenState extends State<FlightManagementScreen> {
  final _scrollController = ScrollController();
  List<Destination> _destinations = [];
  bool _loadingRefs = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDestinations();
      if (mounted) context.read<FlightsState>().loadFlights();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<FlightsState>().loadMore();
    }
  }

  Future<void> _loadDestinations() async {
    try {
      final api = DestinationsApi(context.read<DioClient>());
      _destinations = await api.listAll();
    } on ApiException {
      _destinations = [];
    } finally {
      if (mounted) setState(() => _loadingRefs = false);
    }
  }

  Future<void> _openForm({Flight? flight}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FlightFormScreen(flight: flight)),
    );
    if (changed == true) {
      await context.read<FlightsState>().loadFlights();
    }
  }

  Future<void> _openActions(Flight flight) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FlightActionsSheet(flight: flight),
    );
    if (changed == true) {
      await context.read<FlightsState>().loadFlights();
    }
  }

  Future<void> _deleteFlight(Flight flight) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le vol'),
        content: Text(
          'Voulez-vous vraiment supprimer le vol ${flight.route} du '
          '${Formatters.formatDate(flight.flightDate)} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FlightsApi(context.read<DioClient>()).delete(flight.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vol supprimé.'),
          backgroundColor: Colors.green,
        ),
      );
      await context.read<FlightsState>().loadFlights();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _openFilters() {
    final state = context.read<FlightsState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FlightFilterSheet(
        state: state,
        destinations: _destinations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FlightsState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des vols'),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            icon: Badge(
              isLabelVisible: state.hasFilters,
              child: const Icon(Icons.tune),
            ),
            onPressed: _loadingRefs ? null : _openFilters,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau vol'),
      ),
      body: RefreshIndicator(
        onRefresh: () => state.loadFlights(),
        child: _buildList(state),
      ),
    );
  }

  Widget _buildList(FlightsState state) {
    if (state.loadingFlights && state.flights.isEmpty) {
      return const LoadingView(message: 'Chargement des vols...');
    }
    if (state.flightsError != null && state.flights.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        ErrorView(
          message: state.flightsError!,
          onRetry: () => state.loadFlights(),
        ),
      ]);
    }
    if (state.flights.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const EmptyState(
          message: 'Aucun vol ne correspond aux filtres.',
          icon: Icons.flight_outlined,
        ),
      ]);
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: state.flights.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.flights.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final flight = state.flights[index];
        return Stack(
          children: [
            FlightCard(
              flight: flight,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FlightDetailScreen(
                    flightId: flight.id,
                    initialFlight: flight,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  switch (value) {
                    case 'actions':
                      _openActions(flight);
                      break;
                    case 'edit':
                      _openForm(flight: flight);
                      break;
                    case 'delete':
                      _deleteFlight(flight);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'actions',
                    child: Text('Actions (retard, report, annulation)'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Modifier'),
                  ),
                  if (widget.allowDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FlightFilterSheet extends StatefulWidget {
  const _FlightFilterSheet({required this.state, required this.destinations});

  final FlightsState state;
  final List<Destination> destinations;

  @override
  State<_FlightFilterSheet> createState() => _FlightFilterSheetState();
}

class _FlightFilterSheetState extends State<_FlightFilterSheet> {
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final state = widget.state;
    _date = state.date != null ? DateTime.tryParse(state.date!) : null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filtres',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Date'),
              subtitle: Text(_date == null ? 'Toutes' : Formatters.formatDateObj(_date)),
              trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _date = null),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: state.day,
              decoration: const InputDecoration(labelText: 'Jour'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Tous')),
                for (final day in AppConstants.weekDisplayOrder)
                  DropdownMenuItem<int?>(
                    value: day,
                    child: Text(AppConstants.dayLabel(day)),
                  ),
              ],
              onChanged: (value) => setState(() => state.setDay(value)),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              value: state.destinationId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Destination'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Toutes')),
                for (final destination in widget.destinations)
                  DropdownMenuItem<int?>(
                    value: destination.id,
                    child: Text(
                      '${destination.code} — ${destination.city}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => state.setDestination(value)),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              value: state.status,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Tous')),
                for (final status in AppConstants.flightStatuses)
                  DropdownMenuItem<String?>(
                    value: status,
                    child: Text(AppConstants.flightStatusLabel(status)),
                  ),
              ],
              onChanged: (value) => setState(() => state.setStatus(value)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                state.setDate(
                  _date == null ? null : Formatters.toApiDate(_date!),
                );
                Navigator.of(context).pop();
                state.loadFlights();
              },
              child: const Text('Appliquer'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() => _date = null);
                state.resetFilters();
                Navigator.of(context).pop();
                state.loadFlights();
              },
              child: const Text('Réinitialiser les filtres'),
            ),
          ],
        ),
      ),
    );
  }
}
