import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/api/destinations_api.dart';
import '../../data/api/dio_client.dart';
import '../../data/api/flights_api.dart';
import '../../data/models/destination.dart';
import '../../data/models/flight.dart';

/// Création / modification d'un vol (agent / administrateur).
class FlightFormScreen extends StatefulWidget {
  const FlightFormScreen({super.key, this.flight});

  final Flight? flight;

  @override
  State<FlightFormScreen> createState() => _FlightFormScreenState();
}

class _FlightFormScreenState extends State<FlightFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _observationController = TextEditingController();

  DateTime? _date;
  String? _registrationTime = '08:00';
  String? _departureTime = '10:00';
  String? _arrivalTime = '12:00';
  int? _originId;
  int? _destinationId;
  String _status = AppConstants.statusScheduled;
  bool _isExceptional = false;

  List<Destination> _destinations = [];
  bool _loadingDestinations = true;
  bool _saving = false;

  bool get _isEdit => widget.flight != null;

  @override
  void initState() {
    super.initState();
    final flight = widget.flight;
    if (flight != null) {
      _date = DateTime.tryParse(flight.flightDate);
      _codeController.text = flight.flightCode;
      _observationController.text = flight.observation;
      _registrationTime = Formatters.formatTime(flight.registrationTime);
      _departureTime = Formatters.formatTime(flight.departureTime);
      _arrivalTime = Formatters.formatTime(flight.arrivalTime);
      _originId = flight.originId;
      _destinationId = flight.destinationId;
      _status = flight.status;
      _isExceptional = flight.isExceptional;
    } else {
      _date = DateTime.now();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDestinations());
  }

  @override
  void dispose() {
    _codeController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    try {
      final api = DestinationsApi(context.read<DioClient>());
      _destinations = await api.listAll(isActive: true);
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _loadingDestinations = false);
    }
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

  Future<void> _pickTime(String current, ValueChanged<String> onPicked) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => onPicked(Formatters.toApiTime(picked.hour, picked.minute)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _originId == null || _destinationId == null) {
      _showError('Veuillez renseigner la date, l\'origine et la destination.');
      return;
    }

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'flight_date': Formatters.toApiDate(_date!),
      'origin': _originId,
      'destination': _destinationId,
      'flight_code': _codeController.text.trim(),
      'registration_time': _registrationTime,
      'departure_time': _departureTime,
      'arrival_time': _arrivalTime,
      'observation': _observationController.text.trim(),
      'is_exceptional': _isExceptional,
      'status': _status,
    };

    try {
      final api = FlightsApi(context.read<DioClient>());
      if (_isEdit) {
        await api.update(widget.flight!.id, payload);
      } else {
        await api.create(payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Vol modifié.' : 'Vol créé.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le vol' : 'Nouveau vol'),
      ),
      body: _loadingDestinations
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Date du vol'),
                    subtitle: Text(
                      _date == null ? 'Non définie' : Formatters.formatDateObj(_date),
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _originId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Origine'),
                    items: [
                      for (final destination in _destinations)
                        DropdownMenuItem(
                          value: destination.id,
                          child: Text('${destination.code} — ${destination.city}'),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? 'Origine obligatoire.' : null,
                    onChanged: (value) => setState(() => _originId = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _destinationId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Destination'),
                    items: [
                      for (final destination in _destinations)
                        DropdownMenuItem(
                          value: destination.id,
                          child: Text('${destination.code} — ${destination.city}'),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? 'Destination obligatoire.' : null,
                    onChanged: (value) => setState(() => _destinationId = value),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    decoration:
                        const InputDecoration(labelText: 'Code du vol (facultatif)'),
                  ),
                  const SizedBox(height: 8),
                  _TimeField(
                    label: 'Heure d\'enregistrement',
                    value: _registrationTime,
                    onTap: () => _pickTime(
                      _registrationTime ?? '08:00',
                      (value) => _registrationTime = value,
                    ),
                  ),
                  _TimeField(
                    label: 'Heure de décollage',
                    value: _departureTime,
                    onTap: () => _pickTime(
                      _departureTime ?? '10:00',
                      (value) => _departureTime = value,
                    ),
                  ),
                  _TimeField(
                    label: 'Heure d\'arrivée',
                    value: _arrivalTime,
                    onTap: () => _pickTime(
                      _arrivalTime ?? '12:00',
                      (value) => _arrivalTime = value,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: [
                      for (final status in AppConstants.flightStatuses)
                        DropdownMenuItem(
                          value: status,
                          child: Text(AppConstants.flightStatusLabel(status)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _observationController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Observation'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vol exceptionnel'),
                    value: _isExceptional,
                    onChanged: (value) => setState(() => _isExceptional = value),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isEdit ? 'Enregistrer' : 'Créer le vol'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.access_time),
      title: Text(label),
      subtitle: Text(value ?? '—'),
      trailing: const Icon(Icons.edit_outlined),
      onTap: onTap,
    );
  }
}
