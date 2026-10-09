import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api/dio_client.dart';

/// Entrée du journal d'audit.
class _AuditLog {
  const _AuditLog({
    required this.id,
    required this.userEmail,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.description,
    this.createdAt,
  });

  final int id;
  final String userEmail;
  final String action;
  final String entityType;
  final String entityId;
  final String description;
  final String? createdAt;

  factory _AuditLog.fromJson(Map<String, dynamic> json) {
    return _AuditLog(
      id: (json['id'] as num).toInt(),
      userEmail: (json['user_email'] ?? '') as String,
      action: (json['action'] ?? '') as String,
      entityType: (json['entity_type'] ?? '') as String,
      entityId: (json['entity_id'] ?? '').toString(),
      description: (json['description'] ?? '') as String,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Journal des actions (réservé à l'administrateur).
class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  static const Map<String, String> _actionLabels = {
    'create': 'Création',
    'update': 'Modification',
    'delete': 'Suppression',
    'login': 'Connexion',
    'logout': 'Déconnexion',
    'login_failed': 'Échec de connexion',
    'permission': 'Permission',
    'notify': 'Notification',
    'publish': 'Publication',
  };

  final _scrollController = ScrollController();
  List<_AuditLog> _logs = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _numPages = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_page < _numPages && !_loading) {
        _page += 1;
        _load(append: true);
      }
    }
  }

  Future<void> _load({bool append = false}) async {
    if (!append) {
      _page = 1;
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loading = true);
    }

    final client = context.read<DioClient>();
    try {
      final response = await client.dio.get<Map<String, dynamic>>(
            '/audit-logs/',
            queryParameters: {'page': _page, 'page_size': 30},
          );
      final data = response.data!;
      final results = (data['results'] as List<dynamic>)
          .map((e) => _AuditLog.fromJson(e as Map<String, dynamic>))
          .toList();
      _numPages = (data['num_pages'] as num?)?.toInt() ?? 1;
      _logs = append ? [..._logs, ...results] : results;
    } catch (error) {
      _error = client.toApiException(error).message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des actions')),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _logs.isEmpty) {
      return const LoadingView(message: 'Chargement de l\'historique...');
    }
    if (_error != null && _logs.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        ErrorView(message: _error!, onRetry: () => _load()),
      ]);
    }
    if (_logs.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const EmptyState(
          message: 'Aucune action enregistrée.',
          icon: Icons.history,
        ),
      ]);
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _logs.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _logs.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final log = _logs[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.history_toggle_off),
            title: Text(
              _actionLabels[log.action] ?? log.action,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.description),
                const SizedBox(height: 4),
                Text(
                  '${log.userEmail}'
                  '${log.entityType.isEmpty ? '' : ' • ${log.entityType} ${log.entityId}'}'
                  ' • ${Formatters.formatDateTime(log.createdAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  bool get _hasMore => _page < _numPages;
}
