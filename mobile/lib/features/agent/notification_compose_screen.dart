import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/api/destinations_api.dart';
import '../../data/api/dio_client.dart';
import '../../data/api/flights_api.dart';
import '../../data/api/notifications_api.dart';
import '../../data/models/destination.dart';
import '../../data/models/flight.dart';

/// Composition d'une notification ciblée par un agent.
///
/// IMPORTANT : avant tout envoi, un écran de confirmation affiche le titre,
/// le message et la description résolue des destinataires.
class NotificationComposeScreen extends StatefulWidget {
  const NotificationComposeScreen({super.key, this.initialFlight});

  final Flight? initialFlight;

  @override
  State<NotificationComposeScreen> createState() =>
      _NotificationComposeScreenState();
}

class _NotificationComposeScreenState extends State<NotificationComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _dedupController = TextEditingController();

  static const List<String> _categories = [
    'new_flight',
    'registration_time_changed',
    'departure_time_changed',
    'delay',
    'postpone',
    'cancellation',
    'boarding',
    'arrival',
    'announcement',
    'urgent',
    'schedule_change',
  ];

  String _category = 'announcement';
  String _targetType = 'all_workers';
  int? _destinationId;
  int? _routeOriginId;
  int? _routeDestinationId;
  int? _flightId;
  bool _isUrgent = false;

  bool _step2 = false;
  bool _sending = false;

  List<Destination> _destinations = [];
  List<Flight> _flights = [];
  bool _loadingRefs = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialFlight != null) {
      _targetType = 'flight';
      _flightId = widget.initialFlight!.id;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReferences());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _dedupController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    final dio = context.read<DioClient>();
    try {
      final destinations = await DestinationsApi(dio).listAll(isActive: true);
      _destinations = destinations;
    } on ApiException {
      _destinations = [];
    }
    try {
      final flights = await FlightsApi(dio).upcoming(limit: 50);
      final initial = widget.initialFlight;
      if (initial != null && !flights.any((f) => f.id == initial.id)) {
        flights.insert(0, initial);
      }
      _flights = flights;
    } on ApiException {
      _flights = [];
    }
    if (mounted) setState(() => _loadingRefs = false);
  }

  String _destinationLabel(int? id) {
    if (id == null) return '';
    final match = _destinations.where((d) => d.id == id);
    if (match.isEmpty) return '';
    final d = match.first;
    return '${d.code} — ${d.city}';
  }

  Flight? get _selectedFlight {
    if (_flightId == null) return null;
    final match = _flights.where((f) => f.id == _flightId);
    return match.isEmpty ? null : match.first;
  }

  /// Description lisible des destinataires résolus (affichée avant envoi).
  String _targetDescription() {
    switch (_targetType) {
      case 'destination':
        final label = _destinationLabel(_destinationId);
        return label.isEmpty
            ? 'Destination non définie'
            : 'Intéressés par la destination $label';
      case 'route':
        final origin = _destinationLabel(_routeOriginId);
        final dest = _destinationLabel(_routeDestinationId);
        if (origin.isEmpty || dest.isEmpty) return 'Trajet non défini';
        return 'Intéressés par le trajet $origin → $dest';
      case 'flight':
        final flight = _selectedFlight;
        if (flight == null) return 'Vol non défini';
        final origin = flight.originDetail?.code ?? '';
        final dest = flight.destinationDetail?.code ?? '';
        return 'Concernés par le vol $origin → $dest du '
            '${Formatters.formatDate(flight.flightDate)} à '
            '${Formatters.formatTime(flight.departureTime)}';
      case 'all_workers':
      default:
        return 'Tous les travailleurs';
    }
  }

  String _categoryLabel(String value) =>
      AppConstants.labelFromMap(AppConstants.notificationCategoryLabels, value);

  void _goToConfirmation() {
    if (!_formKey.currentState!.validate()) return;
    if (_targetType == 'destination' && _destinationId == null) {
      _showError('Veuillez sélectionner une destination.');
      return;
    }
    if (_targetType == 'route' &&
        (_routeOriginId == null || _routeDestinationId == null)) {
      _showError('Veuillez sélectionner le trajet (départ et arrivée).');
      return;
    }
    if (_targetType == 'flight' && _flightId == null) {
      _showError('Veuillez sélectionner un vol.');
      return;
    }
    setState(() => _step2 = true);
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'title': _titleController.text.trim(),
      'message': _messageController.text.trim(),
      'category': _category,
      'target_type': _targetType,
      if (_targetType == 'destination') 'destination': _destinationId,
      if (_targetType == 'route') 'route_origin': _routeOriginId,
      if (_targetType == 'route') 'route_destination': _routeDestinationId,
      if (_targetType == 'flight') 'flight': _flightId,
      'is_urgent': _isUrgent,
      if (_dedupController.text.trim().isNotEmpty)
        'dedup_key': _dedupController.text.trim(),
    };
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final api = NotificationsApi(context.read<DioClient>());
      await api.send(_buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification envoyée.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _showError(error.firstFieldError() ?? error.message);
      if (mounted) setState(() => _step2 = false);
    } finally {
      if (mounted) setState(() => _sending = false);
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
        title: Text(_step2 ? 'Confirmation' : 'Nouvelle notification'),
        leading: _step2
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _sending ? null : () => setState(() => _step2 = false),
              )
            : null,
      ),
      body: _loadingRefs
          ? const Center(child: CircularProgressIndicator())
          : (_step2 ? _buildConfirmation() : _buildForm()),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titre'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Le titre est obligatoire.'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _messageController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Message'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Le message est obligatoire.'
                : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: [
              for (final category in _categories)
                DropdownMenuItem(
                  value: category,
                  child: Text(_categoryLabel(category)),
                ),
            ],
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _targetType,
            decoration: const InputDecoration(labelText: 'Destinataires'),
            items: const [
              DropdownMenuItem(
                  value: 'all_workers', child: Text('Tous les travailleurs')),
              DropdownMenuItem(
                  value: 'destination', child: Text('Par destination')),
              DropdownMenuItem(value: 'route', child: Text('Par trajet')),
              DropdownMenuItem(value: 'flight', child: Text('Par vol')),
            ],
            onChanged: (value) =>
                setState(() => _targetType = value ?? _targetType),
          ),
          if (_targetType == 'destination') ...[
            const SizedBox(height: 14),
            _destinationDropdown(
              label: 'Destination',
              value: _destinationId,
              onChanged: (value) => setState(() => _destinationId = value),
            ),
          ],
          if (_targetType == 'route') ...[
            const SizedBox(height: 14),
            _destinationDropdown(
              label: 'Départ',
              value: _routeOriginId,
              onChanged: (value) => setState(() => _routeOriginId = value),
            ),
            const SizedBox(height: 14),
            _destinationDropdown(
              label: 'Arrivée',
              value: _routeDestinationId,
              onChanged: (value) => setState(() => _routeDestinationId = value),
            ),
          ],
          if (_targetType == 'flight') ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _flightId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Vol'),
              items: [
                for (final flight in _flights)
                  DropdownMenuItem(
                    value: flight.id,
                    child: Text(
                      '${flight.originDetail?.code ?? ''} → '
                      '${flight.destinationDetail?.code ?? ''} '
                      'du ${Formatters.formatDate(flight.flightDate)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _flightId = value),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notification urgente'),
            value: _isUrgent,
            onChanged: (value) => setState(() => _isUrgent = value),
          ),
          TextFormField(
            controller: _dedupController,
            decoration: const InputDecoration(
              labelText: 'Clé anti-doublon (facultatif)',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _goToConfirmation,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continuer vers la confirmation'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation() {
    final flight = _selectedFlight;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Card(
          color: Color(0xFFFFF8E1),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vérifiez les informations ci-dessous avant d\'envoyer la notification.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SummaryRow(label: 'Titre', value: _titleController.text.trim()),
        _SummaryRow(label: 'Catégorie', value: _categoryLabel(_category)),
        _SummaryRow(
          label: 'Urgence',
          value: _isUrgent ? 'Urgente' : 'Normale',
        ),
        const Divider(height: 32),
        const Text('Message',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_messageController.text.trim()),
        const Divider(height: 32),
        const Text('Destinataires',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_targetDescription()),
        if (flight != null) ...[
          const SizedBox(height: 6),
          Text(
            'Vol sélectionné : ${flight.flightCode.isEmpty ? '—' : flight.flightCode}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send),
          label: Text(_sending ? 'Envoi en cours...' : 'Confirmer et envoyer'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _sending ? null : () => setState(() => _step2 = false),
          child: const Text('Modifier'),
        ),
      ],
    );
  }

  Widget _destinationDropdown({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final destination in _destinations)
          DropdownMenuItem(
            value: destination.id,
            child: Text('${destination.code} — ${destination.city}'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
