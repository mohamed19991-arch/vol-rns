import '../models/paged_result.dart';
import '../models/weekly_schedule.dart';
import 'dio_client.dart';

/// Resultat de la generation des vols d'une semaine.
class ScheduleGenerationResult {
  const ScheduleGenerationResult({
    required this.weekStart,
    required this.created,
    required this.skipped,
  });

  final String weekStart;
  final int created;
  final int skipped;

  factory ScheduleGenerationResult.fromJson(Map<String, dynamic> json) {
    return ScheduleGenerationResult(
      weekStart: (json['week_start'] ?? '') as String,
      created: (json['created'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Programme hebdomadaire (recurrent) et generation des vols dates.
class SchedulesApi extends BaseApi {
  SchedulesApi(super.client);

  /// Programme complet groupe par jour (ordre samedi -> vendredi).
  Future<List<WeeklyDay>> week() {
    return guard(() async {
      final response =
          await client.dio.get<List<dynamic>>('/weekly-schedules/week/');
      return (response.data ?? [])
          .map((e) => WeeklyDay.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<PagedResult<WeeklySchedule>> list({
    int? dayOfWeek,
    int? origin,
    int? destination,
    bool? isActive,
    int page = 1,
    int pageSize = 100,
  }) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/weekly-schedules/',
        queryParameters: {
          if (dayOfWeek != null) 'day_of_week': dayOfWeek,
          if (origin != null) 'origin': origin,
          if (destination != null) 'destination': destination,
          if (isActive != null) 'is_active': isActive,
          'page': page,
          'page_size': pageSize,
        },
      );
      return PagedResult.fromJson(response.data!, WeeklySchedule.fromJson);
    });
  }

  Future<WeeklySchedule> create(Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/weekly-schedules/', data: payload);
      return WeeklySchedule.fromJson(response.data!);
    });
  }

  Future<WeeklySchedule> update(int id, Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .patch<Map<String, dynamic>>('/weekly-schedules/$id/', data: payload);
      return WeeklySchedule.fromJson(response.data!);
    });
  }

  Future<void> delete(int id) {
    return guard(() async {
      await client.dio.delete('/weekly-schedules/$id/');
    });
  }

  /// Genere les vols dates d'une semaine a partir du programme habituel.
  Future<ScheduleGenerationResult> generate(String weekStart) {
    return guard(() async {
      final response = await client.dio.post<Map<String, dynamic>>(
        '/weekly-schedules/generate/',
        data: {'week_start': weekStart},
      );
      return ScheduleGenerationResult.fromJson(response.data!);
    });
  }
}
