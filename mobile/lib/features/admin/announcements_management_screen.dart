import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api/announcements_api.dart';
import '../../data/api/dio_client.dart';
import '../../data/models/announcement.dart';
import '../agent/announcement_form_screen.dart';

/// Gestion des annonces : création, modification, publication, suppression.
class AnnouncementsManagementScreen extends StatefulWidget {
  const AnnouncementsManagementScreen({super.key, this.canManage = true});

  final bool canManage;

  @override
  State<AnnouncementsManagementScreen> createState() =>
      _AnnouncementsManagementScreenState();
}

class _AnnouncementsManagementScreenState
    extends State<AnnouncementsManagementScreen> {
  List<Announcement> _announcements = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  AnnouncementsApi get _api => AnnouncementsApi(context.read<DioClient>());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.list(
        status: _statusFilter,
        ordering: '-created_at',
        pageSize: 100,
      );
      _announcements = result.results;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Announcement? announcement}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnnouncementFormScreen(announcement: announcement),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _togglePublish(Announcement announcement) async {
    try {
      if (announcement.isPublished) {
        await _api.unpublish(announcement.id);
        _showMessage('Annonce dépubliée.', success: true);
      } else {
        final confirmed = await _confirm(
          'Publier l\'annonce',
          'Publier « ${announcement.title} » ?'
              '${announcement.sendPush ? ' Une notification push sera envoyée.' : ''}',
        );
        if (confirmed != true) return;
        await _api.publish(announcement.id);
        _showMessage('Annonce publiée.', success: true);
      }
      await _load();
    } on ApiException catch (error) {
      _showMessage(error.firstFieldError() ?? error.message);
    }
  }

  Future<void> _delete(Announcement announcement) async {
    final confirmed = await _confirm(
      'Supprimer l\'annonce',
      'Voulez-vous vraiment supprimer « ${announcement.title} » ?',
    );
    if (confirmed != true) return;

    try {
      await _api.delete(announcement.id);
      _showMessage('Annonce supprimée.', success: true);
      await _load();
    } on ApiException catch (error) {
      _showMessage(error.firstFieldError() ?? error.message);
    }
  }

  Future<bool?> _confirm(String title, String message) {
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
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
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
        title: const Text('Annonces'),
        actions: [
          PopupMenuButton<String?>(
            tooltip: 'Filtrer par statut',
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _statusFilter = value);
              _load();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: null, child: Text('Toutes')),
              PopupMenuItem(value: 'draft', child: Text('Brouillons')),
              PopupMenuItem(value: 'published', child: Text('Publiées')),
            ],
          ),
        ],
      ),
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle annonce'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _announcements.isEmpty) {
      return const LoadingView(message: 'Chargement des annonces...');
    }
    if (_error != null && _announcements.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        ErrorView(message: _error!, onRetry: _load),
      ]);
    }
    if (_announcements.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const EmptyState(
          message: 'Aucune annonce.',
          icon: Icons.campaign_outlined,
        ),
      ]);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _announcements.length,
      itemBuilder: (context, index) {
        final announcement = _announcements[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    _StatusChip(announcement: announcement),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  announcement.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppConstants.labelFromMap(AppConstants.announcementCategoryLabels, announcement.category)}'
                  ' • ${AppConstants.labelFromMap(AppConstants.announcementPriorityLabels, announcement.priority)}'
                  ' • ${AppConstants.labelFromMap(AppConstants.targetTypeLabels, announcement.targetType)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (announcement.publishedAt != null)
                  Text(
                    'Publiée le ${Formatters.formatDateTime(announcement.publishedAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                if (widget.canManage) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _togglePublish(announcement),
                        icon: Icon(
                          announcement.isPublished
                              ? Icons.unpublished
                              : Icons.publish,
                          size: 18,
                        ),
                        label: Text(
                          announcement.isPublished ? 'Dépublier' : 'Publier',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _openForm(announcement: announcement),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _delete(announcement),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final published = announcement.isPublished;
    final color = published ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        announcement.statusLabel.isNotEmpty
            ? announcement.statusLabel
            : AppConstants.labelFromMap(
                AppConstants.announcementStatusLabels,
                announcement.status,
              ),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
