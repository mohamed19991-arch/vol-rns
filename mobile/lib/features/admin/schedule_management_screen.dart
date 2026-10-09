import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api/destinations_api.dart';
import '../../data/api/dio_client.dart';
import '../../data/api/schedules_api.dart';
import '../../data/models/destination.dart';
import '../../data/models/weekly_schedule.dart';

/// Gestion du programme hebdomadaire + génération des vols datés.
class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  List<WeeklySchedule> _schedules = [];
  List<Destination> _destinations = [];
  bool _loading = true;
  String? _error;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  SchedulesApi get _api => SchedulesApi(context.read<DioClient>());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schedules = await _api.list(pageSize: 100);
      _schedules = schedules.results
        ..sort((a, b) => a.dayOfWeek == b.dayOfWeek
            ? a.departureTime.compareTo(b.departureTime)
            : a.dayOfWeek.compareTo(b.dayOfWeek));
      _destinations =
          await DestinationsApi(context.read<DioClient>()).listAll();
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({WeeklySchedule? schedule}) async {
    if (_destinations.isEmpty) {
      _showMessage('Ajoutez d\'abord au moins une destination.');
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ScheduleFormDialog(
        schedule: schedule,
        destinations: _destinations,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(WeeklySchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer du programme'),
        content: Text(
          'Supprimer le vol ${schedule.route} du ${schedule.dayLabel} ?',
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
      await _api.delete(schedule.id);
      _showMessage('Entrée supprimée.', success: true);
      await _load();
    } on ApiException catch (error) {
      _showMessage(error.firstFieldError() ?? error.message);
    }
  }

  Future<void> _generate() async {
    final now = DateTime.now();
    final offset = (now.weekday % 7 - DateTime.saturday + 7) % 7;
    final weekStart = now.subtract(Duration(days: offset));

    final picked = await showDatePicker(
      context: context,
      initialDate: weekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Début de semaine (samedi)',
    );
    if (picked == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Générer les vols'),
        content: Text(
          'Générer les vols de la semaine du '
          '${Formatters.formatDateObj(picked)} à partir du programme ? '
          'Les vols déjà existants seront ignorés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _generating = true);
    try {
      final result = await _api.generate(Formatters.toApiDate(picked));
      _showMessage(
        'Génération terminée : ${result.created} vol(s) créé(s), '
        '${result.skipped} ignoré(s).',
        success: true,
      );
    } on ApiException catch (error) {
      _showMessage(error.firstFieldError() ?? error.message);
    } finally {
      if (mounted) setState(() => _generating = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programme hebdomadaire'),
        actions: [
          IconButton(
            tooltip: 'Générer les vols d\'une semaine',
            icon: _generating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.playlist_add_check),
            onPressed: _generating ? null : _generate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter au programme'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _schedules.isEmpty) {
      return const LoadingView(message: 'Chargement du programme...');
    }
    if (_error != null && _schedules.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        ErrorView(message: _error!, onRetry: _load),
      ]);
    }
    if (_schedules.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const EmptyState(
          message: 'Le programme hebdomadaire est vide.',
          icon: Icons.calendar_view_week_outlined,
        ),
      ]);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _schedules.length,
      itemBuilder: (context, index) {
        final schedule = _schedules[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(schedule.dayLabel.isNotEmpty
                  ? schedule.dayLabel.substring(0, 3)
                  : '?'),
            ),
            title: Text(
              '${schedule.originDetail?.code ?? ''} → '
              '${schedule.destinationDetail?.code ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${schedule.dayLabel} • Enreg. '
              '${Formatters.formatTime(schedule.registrationTime)} • Départ '
              '${Formatters.formatTime(schedule.departureTime)}',
            ),
            onTap: () => _openForm(schedule: schedule),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!schedule.isActive)
                  const Icon(Icons.visibility_off, size: 18, color: Colors.grey),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _delete(schedule),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleFormDialog extends StatefulWidget {
  const _ScheduleFormDialog({this.schedule, required this.destinations});

  final WeeklySchedule? schedule;
  final List<Destination> destinations;

  @override
  State<_ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<_ScheduleFormDialog> {
  final _codeController = TextEditingController();

  int _dayOfWeek = 5; // Samedi par défaut
  int? _originId;
  int? _destinationId;
  String _registrationTime = '08:00';
  String _departureTime = '10:00';
  String _arrivalTime = '12:00';
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    if (s != null) {
      _codeController.text = s.flightCode;
      _dayOfWeek = s.dayOfWeek;
      _originId = s.originId;
      _destinationId = s.destinationId;
      _registrationTime = Formatters.formatTime(s.registrationTime);
      _departureTime = Formatters.formatTime(s.departureTime);
      _arrivalTime = Formatters.formatTime(s.arrivalTime);
      _isActive = s.isActive;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(String current, ValueChanged<String> onPicked) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      onPicked(Formatters.toApiTime(picked.hour, picked.minute));
    }
  }

  Future<void> _save() async {
    if (_originId == null || _destinationId == null) {
      _showError('Origine et destination obligatoires.');
      return;
    }
    setState(() => _saving = true);

    final payload = {
      'day_of_week': _dayOfWeek,
      'origin': _originId,
      'destination': _destinationId,
      'flight_code': _codeController.text.trim(),
      'registration_time': _registrationTime,
      'departure_time': _departureTime,
      'arrival_time': _arrivalTime,
      'is_active': _isActive,
    };

    try {
      final api = SchedulesApi(context.read<DioClient>());
      if (_isEdit) {
        await api.update(widget.schedule!.id, payload);
      } else {
        await api.create(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _showError(error.firstFieldError() ?? error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier l\'entrée' : 'Nouvelle entrée du programme'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _dayOfWeek,
                decoration: const InputDecoration(labelText: 'Jour'),
                items: [
                  for (final day in AppConstants.weekDisplayOrder)
                    DropdownMenuItem(
                      value: day,
                      child: Text(AppConstants.dayLabel(day)),
                    ),
                ],
                onChanged: (value) => setState(() => _dayOfWeek = value ?? 5),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _originId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Origine'),
                items: [
                  for (final destination in widget.destinations)
                    DropdownMenuItem(
                      value: destination.id,
                      child: Text('${destination.code} — ${destination.city}'),
                    ),
                ],
                onChanged: (value) => setState(() => _originId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _destinationId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Destination'),
                items: [
                  for (final destination in widget.destinations)
                    DropdownMenuItem(
                      value: destination.id,
                      child: Text('${destination.code} — ${destination.city}'),
                    ),
                ],
                onChanged: (value) => setState(() => _destinationId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                decoration:
                    const InputDecoration(labelText: 'Code du vol (facultatif)'),
              ),
              const SizedBox(height: 8),
              _timeTile('Enregistrement', _registrationTime,
                  (value) => setState(() => _registrationTime = value)),
              _timeTile('Décollage', _departureTime,
                  (value) => setState(() => _departureTime = value)),
              _timeTile('Arrivée', _arrivalTime,
                  (value) => setState(() => _arrivalTime = value)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Actif'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_isEdit ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }

  Widget _timeTile(String label, String value, ValueChanged<String> onPicked) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.access_time),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _pickTime(value, onPicked),
    );
  }
}
