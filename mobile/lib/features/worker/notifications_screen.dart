import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../state/notifications_state.dart';

/// Centre de notifications du travailleur.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsState>().load();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationsState>().loadMore();
    }
  }

  Future<void> _refresh() => context.read<NotificationsState>().load();

  Future<void> _markRead(int id) async {
    try {
      await context.read<NotificationsState>().markRead(id);
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await context.read<NotificationsState>().markAllRead();
      _showMessage('Toutes les notifications ont été marquées comme lues.',
          success: true);
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationsState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            IconButton(
              tooltip: 'Tout marquer comme lu',
              icon: const Icon(Icons.done_all),
              onPressed: _markAllRead,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(NotificationsState state) {
    if (state.loading && state.items.isEmpty) {
      return const LoadingView(message: 'Chargement des notifications...');
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        ErrorView(message: state.error!, onRetry: _refresh),
      ]);
    }
    if (state.items.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const EmptyState(
          message: 'Aucune notification.',
          icon: Icons.notifications_none,
        ),
      ]);
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final notification = state.items[index];
        return Card(
          color: notification.isRead ? null : Colors.blue.shade50,
          child: ListTile(
            leading: Icon(
              notification.isUrgent
                  ? Icons.warning_amber_rounded
                  : Icons.notifications_outlined,
              color: notification.isUrgent ? Colors.red : null,
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight:
                    notification.isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(notification.message),
                const SizedBox(height: 4),
                Text(
                  '${notification.categoryLabel} • '
                  '${Formatters.formatDateTime(notification.createdAt ?? notification.sentAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            isThreeLine: true,
            onTap: notification.isRead
                ? null
                : () => _markRead(notification.id),
          ),
        );
      },
    );
  }
}
