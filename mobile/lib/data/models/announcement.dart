/// Annonce administrative generale ou ciblee.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.categoryLabel,
    required this.priority,
    required this.priorityLabel,
    this.authorEmail = '',
    this.publishedAt,
    this.expiresAt,
    this.targetType = 'all_workers',
    this.targetDestination,
    this.targetRouteOrigin,
    this.targetRouteDestination,
    this.status = 'draft',
    this.statusLabel = '',
    this.sendPush = false,
    this.createdAt,
  });

  final int id;
  final String title;
  final String content;
  final String category;
  final String categoryLabel;
  final String priority;
  final String priorityLabel;
  final String authorEmail;
  final String? publishedAt;
  final String? expiresAt;
  final String targetType;
  final int? targetDestination;
  final int? targetRouteOrigin;
  final int? targetRouteDestination;
  final String status;
  final String statusLabel;
  final bool sendPush;
  final String? createdAt;

  bool get isPublished => status == 'published';

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      category: (json['category'] ?? 'general') as String,
      categoryLabel: (json['category_label'] ?? '') as String,
      priority: (json['priority'] ?? 'normal') as String,
      priorityLabel: (json['priority_label'] ?? '') as String,
      authorEmail: (json['author_email'] ?? '') as String,
      publishedAt: json['published_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      targetType: (json['target_type'] ?? 'all_workers') as String,
      targetDestination: (json['target_destination'] as num?)?.toInt(),
      targetRouteOrigin: (json['target_route_origin'] as num?)?.toInt(),
      targetRouteDestination: (json['target_route_destination'] as num?)?.toInt(),
      status: (json['status'] ?? 'draft') as String,
      statusLabel: (json['status_label'] ?? '') as String,
      sendPush: (json['send_push'] ?? false) as bool,
      createdAt: json['created_at'] as String?,
    );
  }
}
