import 'destination.dart';

/// Entree du programme hebdomadaire (vol recurrent).
class WeeklySchedule {
  const WeeklySchedule({
    required this.id,
    required this.dayOfWeek,
    required this.dayLabel,
    required this.originId,
    required this.destinationId,
    required this.flightCode,
    required this.registrationTime,
    required this.departureTime,
    required this.arrivalTime,
    this.originDetail,
    this.destinationDetail,
    this.isActive = true,
  });

  final int id;
  final int dayOfWeek;
  final String dayLabel;
  final int originId;
  final int destinationId;
  final String flightCode;
  final String registrationTime;
  final String departureTime;
  final String arrivalTime;
  final DestinationBrief? originDetail;
  final DestinationBrief? destinationDetail;
  final bool isActive;

  String get route {
    final o = originDetail?.code ?? '';
    final d = destinationDetail?.code ?? '';
    return '$o → $d';
  }

  factory WeeklySchedule.fromJson(Map<String, dynamic> json) {
    return WeeklySchedule(
      id: (json['id'] as num).toInt(),
      dayOfWeek: (json['day_of_week'] as num).toInt(),
      dayLabel: (json['day_label'] ?? '') as String,
      originId: (json['origin'] as num).toInt(),
      destinationId: (json['destination'] as num).toInt(),
      flightCode: (json['flight_code'] ?? '') as String,
      registrationTime: (json['registration_time'] ?? '') as String,
      departureTime: (json['departure_time'] ?? '') as String,
      arrivalTime: (json['arrival_time'] ?? '') as String,
      originDetail: json['origin_detail'] != null
          ? DestinationBrief.fromJson(json['origin_detail'] as Map<String, dynamic>)
          : null,
      destinationDetail: json['destination_detail'] != null
          ? DestinationBrief.fromJson(
              json['destination_detail'] as Map<String, dynamic>)
          : null,
      isActive: (json['is_active'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toPayload() => {
        'day_of_week': dayOfWeek,
        'origin': originId,
        'destination': destinationId,
        'flight_code': flightCode,
        'registration_time': registrationTime,
        'departure_time': departureTime,
        'arrival_time': arrivalTime,
        'is_active': isActive,
      };
}

/// Groupe de vols recurrents pour un jour donne.
class WeeklyDay {
  const WeeklyDay({
    required this.dayOfWeek,
    required this.dayLabel,
    required this.flights,
  });

  final int dayOfWeek;
  final String dayLabel;
  final List<WeeklySchedule> flights;

  factory WeeklyDay.fromJson(Map<String, dynamic> json) {
    final list = (json['flights'] as List<dynamic>? ?? [])
        .map((e) => WeeklySchedule.fromJson(e as Map<String, dynamic>))
        .toList();
    return WeeklyDay(
      dayOfWeek: (json['day_of_week'] as num).toInt(),
      dayLabel: (json['day_label'] ?? '') as String,
      flights: list,
    );
  }
}
