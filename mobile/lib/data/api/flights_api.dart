import '../models/change_log.dart';
import '../models/flight.dart';
import '../models/paged_result.dart';
import 'dio_client.dart';

/// Vols : listes, filtres, detail, historique et actions metier.
class FlightsApi extends BaseApi {
  FlightsApi(super.client);

  Future<PagedResult<Flight>> list({
    String? date,
    String? dateFrom,
    String? dateTo,
    String? status,
    int? day,
    int? origin,
    int? destination,
    String? route,
    String? search,
    String? ordering,
    int page = 1,
    int pageSize = 20,
  }) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/flights/',
        queryParameters: {
          if (date != null && date.isNotEmpty) 'date': date,
          if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
          if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
          if (status != null && status.isNotEmpty) 'status': status,
          if (day != null) 'day': day,
          if (origin != null) 'origin': origin,
          if (destination != null) 'destination': destination,
          if (route != null && route.isNotEmpty) 'route': route,
          if (search != null && search.isNotEmpty) 'search': search,
          if (ordering != null && ordering.isNotEmpty) 'ordering': ordering,
          'page': page,
          'page_size': pageSize,
        },
      );
      return PagedResult.fromJson(response.data!, Flight.fromJson);
    });
  }

  Future<PagedResult<Flight>> today({int page = 1, int pageSize = 50}) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/flights/today/',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      return PagedResult.fromJson(response.data!, Flight.fromJson);
    });
  }

  Future<List<Flight>> upcoming({int limit = 10}) {
    return guard(() async {
      final response = await client.dio.get<List<dynamic>>(
        '/flights/upcoming/',
        queryParameters: {'limit': limit},
      );
      return (response.data ?? [])
          .map((e) => Flight.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Flight> detail(int id) {
    return guard(() async {
      final response = await client.dio.get<Map<String, dynamic>>('/flights/$id/');
      return Flight.fromJson(response.data!);
    });
  }

  Future<List<ChangeLog>> history(int id) {
    return guard(() async {
      final response =
          await client.dio.get<List<dynamic>>('/flights/$id/history/');
      return (response.data ?? [])
          .map((e) => ChangeLog.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Flight> delay(
    int id, {
    required String newDepartureTime,
    String observation = '',
  }) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/flights/$id/delay/', data: {
        'new_departure_time': newDepartureTime,
        if (observation.isNotEmpty) 'observation': observation,
      });
      return Flight.fromJson(response.data!);
    });
  }

  Future<Flight> postpone(
    int id, {
    required String newFlightDate,
    String newDepartureTime = '',
    String observation = '',
  }) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/flights/$id/postpone/', data: {
        'new_flight_date': newFlightDate,
        if (newDepartureTime.isNotEmpty) 'new_departure_time': newDepartureTime,
        if (observation.isNotEmpty) 'observation': observation,
      });
      return Flight.fromJson(response.data!);
    });
  }

  Future<Flight> cancel(int id, {String observation = ''}) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/flights/$id/cancel/', data: {
        if (observation.isNotEmpty) 'observation': observation,
      });
      return Flight.fromJson(response.data!);
    });
  }

  Future<Flight> observe(int id, {required String observation}) {
    return guard(() async {
      final response = await client.dio
          .post<Map<String, dynamic>>('/flights/$id/observe/', data: {
        'observation': observation,
      });
      return Flight.fromJson(response.data!);
    });
  }

  Future<Flight> create(Map<String, dynamic> payload) {
    return guard(() async {
      final response =
          await client.dio.post<Map<String, dynamic>>('/flights/', data: payload);
      return Flight.fromJson(response.data!);
    });
  }

  Future<Flight> update(int id, Map<String, dynamic> payload) {
    return guard(() async {
      final response = await client.dio
          .patch<Map<String, dynamic>>('/flights/$id/', data: payload);
      return Flight.fromJson(response.data!);
    });
  }

  Future<void> delete(int id) {
    return guard(() async {
      await client.dio.delete('/flights/$id/');
    });
  }
}
