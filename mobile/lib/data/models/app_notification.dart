/// Notification recue dans la boite de reception d'un utilisateur.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.categoryLabel,
    this.flightId,
    this.flightRoute = '',
    this.isUrgent = false,
    this.isRead = false,
    this.sentAt,
    this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final String category;
  final String categoryLabel;
  final int? flightId;
  final String flightRoute;
  final bool isUrgent;
  final bool isRead;
  final String? sentAt;
  final String? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      message: (json['message'] ?? '') as String,
      category: (json['category'] ?? '') as String,
      categoryLabel: (json['category_label'] ?? '') as String,
      flightId: (json['flight'] as num?)?.toInt(),
      flightRoute: (json['flight_route'] ?? '') as String,
      isUrgent: (json['is_urgent'] ?? false) as bool,
      isRead: (json['is_read'] ?? false) as bool,
      sentAt: json['sent_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        category: category,
        categoryLabel: categoryLabel,
        flightId: flightId,
        flightRoute: flightRoute,
        isUrgent: isUrgent,
        isRead: isRead ?? this.isRead,
        sentAt: sentAt,
        createdAt: createdAt,
      );
}
