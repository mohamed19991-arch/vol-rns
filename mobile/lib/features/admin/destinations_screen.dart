import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api/destinations_api.dart';
import '../../data/api/dio_client.dart';
import '../../data/models/destination.dart';

/// Gestion des destinations (référentiel des villes / aéroports).
class DestinationsScreen extends StatefulWidget {
  const DestinationsScreen({super.key});

  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  List<Destination> _destinations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DestinationsApi get _api => DestinationsApi(context.read<DioClient>());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _destinations = await _api.listAll();
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Destination? destination}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _DestinationFormDialog(destination: destination),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(Destination destination) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la destination'),
        content: Text(
          'Voulez-vous vraiment supprimer ${destination.code} — '
          '${destination.name} ? Cette action est impossible si des vols '
          'l\'utilisent.',
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
      await _api.delete(destination.id);
      _showMessage('Destination supprimée.', success: true);
      await _load();
    } on ApiException catch (error) {
      _showMessage(error.firstFieldError() ?? error.message);
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
      appBar: AppBar(title: const Text('Destinations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nouvelle destination'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _destinations.isEmpty) {
      return const LoadingView(message: 'Chargement des destinations...');
    }
    if (_error != null && _destinations.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        ErrorView(message: _error!, onRetry: _load),
      ]);
    }
    if (_destinations.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const EmptyState(
          message: 'Aucune destination.',
          icon: Icons.place_outlined,
        ),
      ]);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _destinations.length,
      itemBuilder: (context, index) {
        final destination = _destinations[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(destination.code)),
            title: Text(
              destination.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${destination.city}'
              '${destination.country.isEmpty ? '' : ', ${destination.country}'}',
            ),
            onTap: () => _openForm(destination: destination),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!destination.isActive)
                  const Icon(Icons.visibility_off, size: 18, color: Colors.grey),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _delete(destination),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DestinationFormDialog extends StatefulWidget {
  const _DestinationFormDialog({this.destination});

  final Destination? destination;

  @override
  State<_DestinationFormDialog> createState() => _DestinationFormDialogState();
}

class _DestinationFormDialogState extends State<_DestinationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _airportController = TextEditingController();
  final _countryController = TextEditingController();

  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.destination != null;

  @override
  void initState() {
    super.initState();
    final d = widget.destination;
    if (d != null) {
      _codeController.text = d.code;
      _nameController.text = d.name;
      _cityController.text = d.city;
      _airportController.text = d.airportName;
      _countryController.text = d.country;
      _isActive = d.isActive;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _airportController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = {
      'code': _codeController.text.trim().toUpperCase(),
      'name': _nameController.text.trim(),
      'city': _cityController.text.trim(),
      'airport_name': _airportController.text.trim(),
      'country': _countryController.text.trim(),
      'is_active': _isActive,
    };

    try {
      final api = DestinationsApi(context.read<DioClient>());
      if (_isEdit) {
        await api.update(widget.destination!.id, payload);
      } else {
        await api.create(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.firstFieldError() ?? error.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier la destination' : 'Nouvelle destination'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Code (ex : RNS)'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Code obligatoire.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Nom obligatoire.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'Ville'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _airportController,
                  decoration: const InputDecoration(labelText: 'Aéroport'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Pays'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Destination active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
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
}
