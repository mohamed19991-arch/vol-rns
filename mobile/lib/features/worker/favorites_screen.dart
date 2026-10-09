import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api/dio_client.dart';
import '../../data/api/favorites_api.dart';
import '../../data/models/favorite.dart';

/// Liste des favoris du travailleur : suppression et notifications.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Favorite> _favorites = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  FavoritesApi get _api => FavoritesApi(context.read<DioClient>());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.list(pageSize: 100);
      _favorites = result.results;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Favorite favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le favori'),
        content: Text(
          'Voulez-vous vraiment supprimer le favori « ${favorite.label} » ?',
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
      await _api.delete(favorite.id);
      setState(() => _favorites.removeWhere((f) => f.id == favorite.id));
      _showMessage('Favori supprimé.', success: true);
    } on ApiException catch (error) {
      _showMessage(error.firstFieldError() ?? error.message);
    }
  }

  Future<void> _toggleNotifications(Favorite favorite) async {
    try {
      final updated = await _api.toggleNotifications(favorite.id);
      final index = _favorites.indexWhere((f) => f.id == favorite.id);
      if (index >= 0) setState(() => _favorites[index] = updated);
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
      appBar: AppBar(title: const Text('Mes favoris')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _favorites.isEmpty) {
      return const LoadingView(message: 'Chargement des favoris...');
    }
    if (_error != null && _favorites.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        ErrorView(message: _error!, onRetry: _load),
      ]);
    }
    if (_favorites.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const EmptyState(
          message: 'Vous n\'avez aucun favori pour le moment.',
          icon: Icons.star_border,
        ),
      ]);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        return Card(
          child: ListTile(
            leading: Icon(_iconFor(favorite.favoriteType)),
            title: Text(
              favorite.label.isEmpty ? 'Favori' : favorite.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${AppConstants.labelFromMap(AppConstants.favoriteTypeLabels, favorite.favoriteType)}'
              '${_detailText(favorite)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: favorite.notificationsEnabled,
                  onChanged: (_) => _toggleNotifications(favorite),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _delete(favorite),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'route':
        return Icons.route_outlined;
      case 'flight':
        return Icons.flight_outlined;
      case 'destination':
      default:
        return Icons.place_outlined;
    }
  }

  String _detailText(Favorite favorite) {
    if (favorite.favoriteType == 'flight' && favorite.flightDetail != null) {
      final f = favorite.flightDetail!;
      return ' — ${f.flightDate}';
    }
    return '';
  }
}
