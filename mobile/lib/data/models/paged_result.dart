/// Resultat pagine renvoye par l'API DRF.
class PagedResult<T> {
  const PagedResult({
    required this.count,
    required this.numPages,
    required this.page,
    required this.pageSize,
    required this.results,
    this.next,
    this.previous,
  });

  final int count;
  final int numPages;
  final int page;
  final int pageSize;
  final List<T> results;
  final String? next;
  final String? previous;

  bool get hasMore => next != null && next!.isNotEmpty;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawResults = (json['results'] as List<dynamic>? ?? []);
    return PagedResult<T>(
      count: (json['count'] as num?)?.toInt() ?? 0,
      numPages: (json['num_pages'] as num?)?.toInt() ?? 1,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? rawResults.length,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: rawResults
          .map((e) => itemParser(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static PagedResult<T> empty<T>() => PagedResult<T>(
        count: 0,
        numPages: 0,
        page: 1,
        pageSize: 0,
        results: const [],
      );
}
