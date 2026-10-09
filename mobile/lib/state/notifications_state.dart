import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../data/api/notifications_api.dart';
import '../data/models/app_notification.dart';

/// Etat du centre de notifications : liste + compteur de non lues.
class NotificationsState extends ChangeNotifier {
  NotificationsState(this._api);

  final NotificationsApi _api;

  List<AppNotification> items = [];
  int unreadCount = 0;
  bool loading = false;
  String? error;

  int _page = 1;
  int _numPages = 1;

  bool get hasMore => _page < _numPages;

  Future<void> refreshUnread() async {
    try {
      unreadCount = await _api.unreadCount();
      notifyListeners();
    } on ApiException {
      // Silencieux : le compteur n'est pas critique.
    }
  }

  Future<void> load({bool reset = true}) async {
    if (reset) _page = 1;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.inbox(page: _page);
      items = reset ? result.results : [...items, ...result.results];
      _numPages = result.numPages;
      unreadCount = items.where((n) => !n.isRead).length;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    _page += 1;
    await load(reset: false);
  }

  Future<void> markRead(int id) async {
    await _api.markRead(id);
    final index = items.indexWhere((n) => n.id == id);
    if (index >= 0 && !items[index].isRead) {
      items[index] = items[index].copyWith(isRead: true);
      if (unreadCount > 0) unreadCount -= 1;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    await _api.markAllRead();
    items = items.map((n) => n.copyWith(isRead: true)).toList();
    unreadCount = 0;
    notifyListeners();
  }
}
