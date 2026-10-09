import 'dio_client.dart';

/// Statistique par destination.
class DestinationStat {
  const DestinationStat({
    required this.code,
    required this.name,
    required this.total,
  });

  final String code;
  final String name;
  final int total;

  factory DestinationStat.fromJson(Map<String, dynamic> json) {
    return DestinationStat(
      code: (json['destination__code'] ?? '') as String,
      name: (json['destination__name'] ?? '') as String,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Statistiques sur les vols (agent / administrateur).
class FlightStats {
  const FlightStats({
    required this.totalFlights,
    required this.byStatus,
    required this.scheduled,
    required this.delayed,
    required this.postponed,
    required this.cancelled,
    required this.byDestination,
  });

  final int totalFlights;
  final Map<String, int> byStatus;
  final int scheduled;
  final int delayed;
  final int postponed;
  final int cancelled;
  final List<DestinationStat> byDestination;

  factory FlightStats.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['by_status'] as Map?) ?? {};
    return FlightStats(
      totalFlights: (json['total_flights'] as num?)?.toInt() ?? 0,
      byStatus: rawStatus.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      ),
      scheduled: (json['scheduled'] as num?)?.toInt() ?? 0,
      delayed: (json['delayed'] as num?)?.toInt() ?? 0,
      postponed: (json['postponed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      byDestination: ((json['by_destination'] as List?) ?? [])
          .map((e) => DestinationStat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StatsApi extends BaseApi {
  StatsApi(super.client);

  Future<FlightStats> flightStats({String? dateFrom, String? dateTo}) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/stats/flights/',
        queryParameters: {
          if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
          if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        },
      );
      return FlightStats.fromJson(response.data!);
    });
  }
}
