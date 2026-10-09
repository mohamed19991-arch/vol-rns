import 'destination.dart';

/// Vol associe a une date precise.
///
/// Le meme modele couvre l'element de liste et le detail : les champs de
/// detail (`schedule`, `previous_*`, `created_by_email`...) sont nullables.
class Flight {
  const Flight({
    required this.id,
    required this.flightDate,
    required this.dayOfWeek,
    required this.dayLabel,
    required this.originDetail,
    required this.destinationDetail,
    required this.route,
    required this.flightCode,
    required this.registrationTime,
    required this.departureTime,
    required this.arrivalTime,
    required this.status,
    required this.statusLabel,
    this.observation = '',
    this.isExceptional = false,
    this.isActive = true,
    this.scheduleId,
    this.originId,
    this.destinationId,
    this.previousRegistrationTime,
    this.previousDepartureTime,
    this.previousArrivalTime,
    this.previousDepartureTimeDisplay = '',
    this.createdByEmail = '',
    this.updatedByEmail = '',
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String flightDate; // AAAA-MM-JJ
  final int dayOfWeek;
  final String dayLabel;
  final DestinationBrief? originDetail;
  final DestinationBrief? destinationDetail;
  final String route; // "RNS - ORAN"
  final String flightCode;
  final String registrationTime;
  final String departureTime;
  final String arrivalTime;
  final String status;
  final String statusLabel;
  final String observation;
  final bool isExceptional;
  final bool isActive;

  // Champs disponibles uniquement sur le detail.
  final int? scheduleId;
  final int? originId;
  final int? destinationId;
  final String? previousRegistrationTime;
  final String? previousDepartureTime;
  final String? previousArrivalTime;
  final String previousDepartureTimeDisplay;
  final String createdByEmail;
  final String updatedByEmail;
  final String? createdAt;
  final String? updatedAt;

  factory Flight.fromJson(Map<String, dynamic> json) {
    return Flight(
      id: (json['id'] as num).toInt(),
      flightDate: (json['flight_date'] ?? '') as String,
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
      dayLabel: (json['day_label'] ?? '') as String,
      originDetail: json['origin_detail'] != null
          ? DestinationBrief.fromJson(json['origin_detail'] as Map<String, dynamic>)
          : null,
      destinationDetail: json['destination_detail'] != null
          ? DestinationBrief.fromJson(
              json['destination_detail'] as Map<String, dynamic>)
          : null,
      route: (json['route'] ?? '') as String,
      flightCode: (json['flight_code'] ?? '') as String,
      registrationTime: (json['registration_time'] ?? '') as String,
      departureTime: (json['departure_time'] ?? '') as String,
      arrivalTime: (json['arrival_time'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      statusLabel: (json['status_label'] ?? '') as String,
      observation: (json['observation'] ?? '') as String,
      isExceptional: (json['is_exceptional'] ?? false) as bool,
      isActive: (json['is_active'] ?? true) as bool,
      scheduleId: (json['schedule'] as num?)?.toInt(),
      originId: (json['origin'] as num?)?.toInt(),
      destinationId: (json['destination'] as num?)?.toInt(),
      previousRegistrationTime: json['previous_registration_time'] as String?,
      previousDepartureTime: json['previous_departure_time'] as String?,
      previousArrivalTime: json['previous_arrival_time'] as String?,
      previousDepartureTimeDisplay:
          (json['previous_departure_time_display'] ?? '') as String,
      createdByEmail: (json['created_by_email'] ?? '') as String,
      updatedByEmail: (json['updated_by_email'] ?? '') as String,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}
