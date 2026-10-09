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
import '../../data/models/destination.dart';
import '../../state/flights_state.dart';
import 'flight_detail_screen.dart';

/// Liste des vols du jour avec recherche et filtres.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _routeController = TextEditingController();

  List<Destination> _destinations = [];
  bool _loadingDestinations = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<FlightsState>();
      if (state.date == null) {
        state.setDate(Formatters.toApiDate(DateTime.now()));
      }
      _loadDestinations();
      state.loadFlights();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _routeController.dispose();
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
      _destinations = await api.listAll(isActive: true);
    } on ApiException {
      _destinations = [];
    } finally {
      if (mounted) setState(() => _loadingDestinations = false);
    }
  }

  Future<void> _refresh() async {
    await context.read<FlightsState>().loadFlights();
  }

  Future<void> _pickDate() async {
    final state = context.read<FlightsState>();
    final current = state.date != null ? DateTime.tryParse(state.date!) : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      state.setDate(Formatters.toApiDate(picked));
      await state.loadFlights();
    }
  }

  void _openFilters() {
    final state = context.read<FlightsState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        state: state,
        destinations: _destinations,
        routeController: _routeController,
        onApply: () async {
          Navigator.of(context).pop();
          await state.loadFlights();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FlightsState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vols'),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            icon: Badge(
              isLabelVisible: state.hasFilters,
              child: const Icon(Icons.tune),
            ),
            onPressed: _loadingDestinations ? null : _openFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(state),
          _buildActiveFilters(state),
          const Divider(height: 1),
          Expanded(child: _buildList(state)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(FlightsState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher un vol, une ville, un code...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    state.setSearch('');
                    state.loadFlights();
                    setState(() {});
                  },
                ),
        ),
        onSubmitted: (value) {
          state.setSearch(value.trim());
          state.loadFlights();
        },
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildActiveFilters(FlightsState state) {
    final chips = <Widget>[];

    chips.add(ActionChip(
      avatar: const Icon(Icons.event, size: 16),
      label: Text(
        state.date != null ? Formatters.formatDate(state.date) : 'Date',
      ),
      onPressed: _pickDate,
    ));

    if (state.status != null) {
      chips.add(Chip(
        label: Text(AppConstants.flightStatusLabel(state.status)),
        onDeleted: () {
          state.setStatus(null);
          state.loadFlights();
        },
      ));
    }
    if (state.day != null) {
      chips.add(Chip(
        label: Text(AppConstants.dayLabel(state.day)),
        onDeleted: () {
          state.setDay(null);
          state.loadFlights();
        },
      ));
    }
    if (state.destinationId != null) {
      chips.add(Chip(
        label: Text(_destinationLabel(state.destinationId!)),
        onDeleted: () {
          state.setDestination(null);
          state.loadFlights();
        },
      ));
    }
    if (state.route != null && state.route!.isNotEmpty) {
      chips.add(Chip(
        label: Text(state.route!),
        onDeleted: () {
          _routeController.clear();
          state.setRoute(null);
          state.loadFlights();
        },
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final chip in chips) ...[
            chip,
            const SizedBox(width: 8),
          ],
          if (state.hasFilters)
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                _routeController.clear();
                state.resetFilters();
                state.setDate(Formatters.toApiDate(DateTime.now()));
                state.loadFlights();
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Réinitialiser'),
            ),
        ],
      ),
    );
  }

  String _destinationLabel(int id) {
    final match = _destinations.where((d) => d.id == id);
    return match.isEmpty ? 'Destination' : match.first.code;
  }

  Widget _buildList(FlightsState state) {
    if (state.loadingFlights && state.flights.isEmpty) {
      return const LoadingView(message: 'Chargement des vols...');
    }
    if (state.flightsError != null && state.flights.isEmpty) {
      return ErrorView(message: state.flightsError!, onRetry: _refresh);
    }
    if (state.flights.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            const EmptyState(
              message: 'Aucun vol ne correspond à votre recherche.',
              icon: Icons.flight_outlined,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: state.flights.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.flights.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final flight = state.flights[index];
          return FlightCard(
            flight: flight,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FlightDetailScreen(flightId: flight.id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.state,
    required this.destinations,
    required this.routeController,
    required this.onApply,
  });

  final FlightsState state;
  final List<Destination> destinations;
  final TextEditingController routeController;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filtres',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            StatefulBuilder(
              builder: (context, setSheetState) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int?>(
                    value: state.day,
                    decoration:
                        const InputDecoration(labelText: 'Jour de la semaine'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Tous')),
                      for (final day in AppConstants.weekDisplayOrder)
                        DropdownMenuItem<int?>(
                          value: day,
                          child: Text(AppConstants.dayLabel(day)),
                        ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => state.setDay(value)),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int?>(
                    value: state.destinationId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Destination'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Toutes')),
                      for (final destination in destinations)
                        DropdownMenuItem<int?>(
                          value: destination.id,
                          child: Text(
                            '${destination.code} — ${destination.city}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => state.setDestination(value)),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    value: state.status,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Tous')),
                      for (final status in AppConstants.flightStatuses)
                        DropdownMenuItem<String?>(
                          value: status,
                          child: Text(AppConstants.flightStatusLabel(status)),
                        ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => state.setStatus(value)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: routeController,
                    decoration: const InputDecoration(
                      labelText: 'Trajet (ex : RNS-ORAN)',
                      hintText: 'Code départ - code arrivée',
                    ),
                    onChanged: (value) => state.setRoute(value.trim()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onApply,
              child: const Text('Appliquer les filtres'),
            ),
          ],
        ),
      ),
    );
  }
}
