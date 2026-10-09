import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api/dio_client.dart';
import '../../data/api/schedules_api.dart';
import '../../data/models/weekly_schedule.dart';

/// Programme hebdomadaire habituel, groupé par jour (Samedi → Vendredi).
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  List<WeeklyDay> _days = [];
  bool _loading = true;
  String? _error;

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
      final api = SchedulesApi(context.read<DioClient>());
      _days = await api.week();
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _days.any((d) => d.flights.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Programme hebdomadaire')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(hasData),
      ),
    );
  }

  Widget _buildBody(bool hasData) {
    if (_loading && _days.isEmpty) {
      return const LoadingView(message: 'Chargement du programme...');
    }
    if (_error != null && _days.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          ErrorView(message: _error!, onRetry: _load),
        ],
      );
    }
    if (!hasData) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const EmptyState(
            message: 'Aucun vol au programme de la semaine.',
            icon: Icons.calendar_view_week_outlined,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _days.length,
      itemBuilder: (context, index) {
        return _DaySection(day: _days[index]);
      },
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});

  final WeeklyDay day;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: day.flights.isNotEmpty,
        title: Text(
          day.dayLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          day.flights.isEmpty
              ? 'Aucun vol'
              : '${day.flights.length} vol(s)',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        leading: const Icon(Icons.event),
        children: [
          if (day.flights.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Aucun vol programmé ce jour.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            for (final flight in day.flights) _ScheduleTile(flight: flight),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({required this.flight});

  final WeeklySchedule flight;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.flight_outlined, size: 20),
      title: Text(
        '${flight.originDetail?.code ?? ''} → '
        '${flight.destinationDetail?.code ?? ''}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        flight.flightCode.isEmpty ? 'Vol hebdomadaire' : flight.flightCode,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.formatTime(flight.departureTime),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Enreg. ${Formatters.formatTime(flight.registrationTime)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
