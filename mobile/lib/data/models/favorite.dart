import 'destination.dart';
import 'flight.dart';

/// Favori d'un travailleur (destination, trajet ou vol).
class Favorite {
  const Favorite({
    required this.id,
    required this.favoriteType,
    required this.label,
    this.destinationDetail,
    this.routeOriginDetail,
    this.routeDestinationDetail,
    this.flightDetail,
    this.notificationsEnabled = true,
    this.destinationId,
    this.routeOriginId,
    this.routeDestinationId,
    this.flightId,
    this.createdAt,
  });

  final int id;
  final String favoriteType; // destination | route | flight
  final String label;
  final DestinationBrief? destinationDetail;
  final DestinationBrief? routeOriginDetail;
  final DestinationBrief? routeDestinationDetail;
  final Flight? flightDetail;
  final bool notificationsEnabled;
  final int? destinationId;
  final int? routeOriginId;
  final int? routeDestinationId;
  final int? flightId;
  final String? createdAt;

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: (json['id'] as num).toInt(),
      favoriteType: (json['favorite_type'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      destinationDetail: json['destination_detail'] != null
          ? DestinationBrief.fromJson(
              json['destination_detail'] as Map<String, dynamic>)
          : null,
      routeOriginDetail: json['route_origin_detail'] != null
          ? DestinationBrief.fromJson(
              json['route_origin_detail'] as Map<String, dynamic>)
          : null,
      routeDestinationDetail: json['route_destination_detail'] != null
          ? DestinationBrief.fromJson(
              json['route_destination_detail'] as Map<String, dynamic>)
          : null,
      flightDetail: json['flight_detail'] != null
          ? Flight.fromJson(json['flight_detail'] as Map<String, dynamic>)
          : null,
      notificationsEnabled: (json['notifications_enabled'] ?? true) as bool,
      destinationId: (json['destination'] as num?)?.toInt(),
      routeOriginId: (json['route_origin'] as num?)?.toInt(),
      routeDestinationId: (json['route_destination'] as num?)?.toInt(),
      flightId: (json['flight'] as num?)?.toInt(),
      createdAt: json['created_at'] as String?,
    );
  }
}
