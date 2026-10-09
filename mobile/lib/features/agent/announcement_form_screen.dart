import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/api/announcements_api.dart';
import '../../data/api/destinations_api.dart';
import '../../data/api/dio_client.dart';
import '../../data/models/announcement.dart';
import '../../data/models/destination.dart';

/// Création / modification d'une annonce (agent / administrateur).
class AnnouncementFormScreen extends StatefulWidget {
  const AnnouncementFormScreen({super.key, this.announcement});

  final Announcement? announcement;

  @override
  State<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _category = 'general';
  String _priority = 'normal';
  String _targetType = 'all_workers';
  int? _targetDestination;
  int? _routeOrigin;
  int? _routeDestination;
  DateTime? _expiresAt;
  bool _sendPush = false;
  bool _saving = false;

  List<Destination> _destinations = [];
  bool _loadingDestinations = true;

  bool get _isEdit => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    final a = widget.announcement;
    if (a != null) {
      _titleController.text = a.title;
      _contentController.text = a.content;
      _category = a.category;
      _priority = a.priority;
      _targetType = a.targetType;
      _targetDestination = a.targetDestination;
      _routeOrigin = a.targetRouteOrigin;
      _routeDestination = a.targetRouteDestination;
      _sendPush = a.sendPush;
      _expiresAt = DateTime.tryParse(a.expiresAt ?? '');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDestinations());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: 'Date d\'expiration',
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'category': _category,
      'priority': _priority,
      'target_type': _targetType,
      if (_targetType == 'destination') 'target_destination': _targetDestination,
      if (_targetType == 'route') 'target_route_origin': _routeOrigin,
      if (_targetType == 'route') 'target_route_destination': _routeDestination,
      'send_push': _sendPush,
      if (_expiresAt != null)
        'expires_at':
            '${Formatters.toApiDate(_expiresAt!)}T23:59:00',
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetType == 'destination' && _targetDestination == null) {
      _showError('Veuillez choisir une destination cible.');
      return;
    }
    if (_targetType == 'route' &&
        (_routeOrigin == null || _routeDestination == null)) {
      _showError('Veuillez choisir le trajet cible (départ et arrivée).');
      return;
    }

    setState(() => _saving = true);
    try {
      final api = AnnouncementsApi(context.read<DioClient>());
      if (_isEdit) {
        await api.update(widget.announcement!.id, _buildPayload());
      } else {
        await api.create(_buildPayload());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Annonce modifiée.' : 'Annonce créée.'),
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
        title: Text(_isEdit ? 'Modifier l\'annonce' : 'Nouvelle annonce'),
      ),
      body: Form(
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
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Contenu'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Le contenu est obligatoire.'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [
                for (final entry in AppConstants.announcementCategoryLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Priorité'),
              items: [
                for (final entry in AppConstants.announcementPriorityLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _priority = value ?? _priority),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _targetType,
              decoration: const InputDecoration(labelText: 'Public cible'),
              items: const [
                DropdownMenuItem(value: 'all_workers', child: Text('Tous les travailleurs')),
                DropdownMenuItem(value: 'destination', child: Text('Intéressés par une destination')),
                DropdownMenuItem(value: 'route', child: Text('Intéressés par un trajet')),
              ],
              onChanged: (value) => setState(() => _targetType = value ?? _targetType),
            ),
            if (_targetType == 'destination') ...[
              const SizedBox(height: 14),
              _destinationDropdown(
                label: 'Destination ciblée',
                value: _targetDestination,
                onChanged: (value) => setState(() => _targetDestination = value),
              ),
            ],
            if (_targetType == 'route') ...[
              const SizedBox(height: 14),
              _destinationDropdown(
                label: 'Départ du trajet',
                value: _routeOrigin,
                onChanged: (value) => setState(() => _routeOrigin = value),
              ),
              const SizedBox(height: 14),
              _destinationDropdown(
                label: 'Arrivée du trajet',
                value: _routeDestination,
                onChanged: (value) => setState(() => _routeDestination = value),
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy),
              title: const Text('Date d\'expiration'),
              subtitle: Text(
                _expiresAt == null ? 'Aucune' : Formatters.formatDateObj(_expiresAt),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _expiresAt = null),
              ),
              onTap: _pickExpiry,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Envoyer une notification push'),
              value: _sendPush,
              onChanged: (value) => setState(() => _sendPush = value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving || _loadingDestinations ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Enregistrer' : 'Créer l\'annonce'),
            ),
          ],
        ),
      ),
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
