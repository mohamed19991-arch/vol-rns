import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api/dio_client.dart';
import '../../data/api/stats_api.dart';

/// Statistiques sur les vols (agent / administrateur).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  FlightStats? _stats;
  bool _loading = true;
  String? _error;

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = StatsApi(context.read<DioClient>());
      _stats = await api.flightStats(
        dateFrom: Formatters.toApiDate(_from),
        dateTo: Formatters.toApiDate(_to),
      );
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Période d\'analyse',
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          IconButton(
            tooltip: 'Changer la période',
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _stats == null) {
      return const LoadingView(message: 'Calcul des statistiques...');
    }
    if (_error != null && _stats == null) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        ErrorView(message: _error!, onRetry: _load),
      ]);
    }
    final stats = _stats;
    if (stats == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Du ${Formatters.formatDateObj(_from)} au ${Formatters.formatDateObj(_to)}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppTheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Total des vols',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  '${stats.totalFlights}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StatRow(label: 'Programmés', value: stats.scheduled, status: 'scheduled'),
        _StatRow(label: 'Retardés', value: stats.delayed, status: 'delayed'),
        _StatRow(label: 'Reportés', value: stats.postponed, status: 'postponed'),
        _StatRow(label: 'Annulés', value: stats.cancelled, status: 'cancelled'),
        const SizedBox(height: 16),
        const Text(
          'Répartition par statut',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (stats.byStatus.isEmpty)
          const Text('Aucune donnée.')
        else
          for (final entry in stats.byStatus.entries)
            _StatRow(
              label: AppConstants.flightStatusLabel(entry.key),
              value: entry.value,
              status: entry.key,
            ),
        const SizedBox(height: 16),
        const Text(
          'Vols par destination',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (stats.byDestination.isEmpty)
          const Text('Aucune donnée.')
        else
          for (final destination in stats.byDestination)
            Card(
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text('${destination.code} — ${destination.name}'),
                trailing: Text(
                  '${destination.total}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final int value;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
