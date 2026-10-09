import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../data/api/flights_api.dart';
import '../data/models/flight.dart';

/// Etat des vols : filtres de liste, vols du jour et prochains vols.
class FlightsState extends ChangeNotifier {
  FlightsState(this._api);

  final FlightsApi _api;

  // ---- Filtres de liste -------------------------------------------------
  String? date; // AAAA-MM-JJ
  String? dateFrom;
  String? dateTo;
  String? status;
  int? day;
  int? originId;
  int? destinationId;
  String? route;
  String search = '';

  // ---- Résultats --------------------------------------------------------
  List<Flight> flights = [];
  int _page = 1;
  int _numPages = 1;
  bool loadingFlights = false;
  String? flightsError;

  List<Flight> todayFlights = [];
  bool loadingToday = false;
  String? todayError;

  List<Flight> upcomingFlights = [];
  bool loadingUpcoming = false;
  String? upcomingError;

  bool get hasMore => _page < _numPages;

  bool get hasFilters =>
      (date != null) ||
      (dateFrom != null) ||
      (dateTo != null) ||
      (status != null) ||
      (day != null) ||
      (originId != null) ||
      (destinationId != null) ||
      (route != null && route!.isNotEmpty) ||
      search.isNotEmpty;

  // ---- Vols du jour -----------------------------------------------------
  Future<void> loadToday() async {
    loadingToday = true;
    todayError = null;
    notifyListeners();
    try {
      final result = await _api.today(pageSize: 50);
      todayFlights = result.results;
    } on ApiException catch (e) {
      todayError = e.message;
    } finally {
      loadingToday = false;
      notifyListeners();
    }
  }

  // ---- Prochains vols ---------------------------------------------------
  Future<void> loadUpcoming({int limit = 10}) async {
    loadingUpcoming = true;
    upcomingError = null;
    notifyListeners();
    try {
      upcomingFlights = await _api.upcoming(limit: limit);
    } on ApiException catch (e) {
      upcomingError = e.message;
    } finally {
      loadingUpcoming = false;
      notifyListeners();
    }
  }

  // ---- Liste filtrée ----------------------------------------------------
  Future<void> loadFlights({bool reset = true}) async {
    if (reset) _page = 1;
    loadingFlights = true;
    notifyListeners();
    try {
      final result = await _api.list(
        date: date,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        day: day,
        origin: originId,
        destination: destinationId,
        route: route,
        search: search,
        page: _page,
      );
      flights = reset ? result.results : [...flights, ...result.results];
      _numPages = result.numPages;
      flightsError = null;
    } on ApiException catch (e) {
      flightsError = e.message;
    } finally {
      loadingFlights = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loadingFlights || !hasMore) return;
    _page += 1;
    await loadFlights(reset: false);
  }

  // ---- Mise à jour des filtres -----------------------------------------
  void setDate(String? value) {
    date = value;
    notifyListeners();
  }

  void setDateRange(String? from, String? to) {
    dateFrom = from;
    dateTo = to;
    notifyListeners();
  }

  void setStatus(String? value) {
    status = value;
    notifyListeners();
  }

  void setDay(int? value) {
    day = value;
    notifyListeners();
  }

  void setOrigin(int? value) {
    originId = value;
    notifyListeners();
  }

  void setDestination(int? value) {
    destinationId = value;
    notifyListeners();
  }

  void setRoute(String? value) {
    route = value;
    notifyListeners();
  }

  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void resetFilters() {
    date = null;
    dateFrom = null;
    dateTo = null;
    status = null;
    day = null;
    originId = null;
    destinationId = null;
    route = null;
    search = '';
    notifyListeners();
  }

  /// Remplace un vol dans les listes après une modification.
  void replaceFlight(Flight updated) {
    void replaceIn(List<Flight> list) {
      final index = list.indexWhere((f) => f.id == updated.id);
      if (index >= 0) list[index] = updated;
    }

    replaceIn(flights);
    replaceIn(todayFlights);
    replaceIn(upcomingFlights);
    notifyListeners();
  }
}
