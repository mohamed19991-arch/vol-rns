import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/api/dio_client.dart';
import '../../data/api/flights_api.dart';
import '../../data/models/flight.dart';

/// Feuille d'actions métier sur un vol (agent / administrateur) :
/// retard, report, annulation et observation.
class FlightActionsSheet extends StatefulWidget {
  const FlightActionsSheet({super.key, required this.flight});

  final Flight flight;

  @override
  State<FlightActionsSheet> createState() => _FlightActionsSheetState();
}

class _FlightActionsSheetState extends State<FlightActionsSheet> {
  bool _busy = false;

  FlightsApi get _api => FlightsApi(context.read<DioClient>());

  (int, int) _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length >= 2) {
      return (int.tryParse(parts[0]) ?? 8, int.tryParse(parts[1]) ?? 0);
    }
    return (8, 0);
  }

  Future<String?> _pickTime() async {
    final (hour, minute) = _parseTime(widget.flight.departureTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null) return null;
    return Formatters.toApiTime(picked.hour, picked.minute);
  }

  void _notify(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (error) {
      _notify(error.firstFieldError() ?? error.message, success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delay() async {
    final newTime = await _pickTime();
    if (newTime == null) return;
    final observation = await _askObservation(
      title: 'Retard',
      hint: 'Motif du retard (facultatif)',
    );
    if (observation == null) return;

    await _run(() async {
      await _api.delay(
        widget.flight.id,
        newDepartureTime: newTime,
        observation: observation,
      );
      _notify('Vol marqué comme retardé.');
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _postpone() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(widget.flight.flightDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Nouvelle date du vol',
    );
    if (date == null) return;

    final newTime = await _pickTime();
    final observation = await _askObservation(
      title: 'Report',
      hint: 'Motif du report (facultatif)',
    );
    if (observation == null) return;

    final confirmed = await _confirm(
      title: 'Confirmer le report',
      message: 'Le vol sera reporté au ${Formatters.formatDateObj(date)}'
          '${newTime != null ? ' à $newTime' : ''}. Continuer ?',
    );
    if (confirmed != true) return;

    await _run(() async {
      await _api.postpone(
        widget.flight.id,
        newFlightDate: Formatters.toApiDate(date),
        newDepartureTime: newTime ?? '',
        observation: observation,
      );
      _notify('Vol reporté.');
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _cancel() async {
    final observation = await _askObservation(
      title: 'Annulation',
      hint: 'Motif de l\'annulation',
      required: true,
    );
    if (observation == null) return;

    final confirmed = await _confirm(
      title: 'Confirmer l\'annulation',
      message: 'Cette action annulera définitivement le vol pour les voyageurs. '
          'Confirmer ?',
    );
    if (confirmed != true) return;

    await _run(() async {
      await _api.cancel(widget.flight.id, observation: observation);
      _notify('Vol annulé.');
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _observe() async {
    final observation = await _askObservation(
      title: 'Observation',
      hint: 'Saisir une observation',
      required: true,
    );
    if (observation == null) return;

    await _run(() async {
      await _api.observe(widget.flight.id, observation: observation);
      _notify('Observation enregistrée.');
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<String?> _askObservation({
    required String title,
    required String hint,
    bool required = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (required && value.isEmpty) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flight = widget.flight;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${flight.originDetail?.code ?? ''} → '
                    '${flight.destinationDetail?.code ?? ''}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                StatusBadge(status: flight.status, label: flight.statusLabel),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${Formatters.formatDate(flight.flightDate)} • Départ '
              '${Formatters.formatTime(flight.departureTime)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.orange),
                title: const Text('Signaler un retard'),
                subtitle: const Text('Modifier l\'heure de décollage'),
                onTap: _delay,
              ),
              ListTile(
                leading: const Icon(Icons.event_repeat, color: Colors.amber),
                title: const Text('Reporter le vol'),
                subtitle: const Text('Changer la date / l\'heure'),
                onTap: _postpone,
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Annuler le vol'),
                onTap: _cancel,
              ),
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.blueGrey),
                title: const Text('Ajouter une observation'),
                onTap: _observe,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
