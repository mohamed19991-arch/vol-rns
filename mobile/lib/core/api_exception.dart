/// Exception applicative exposee a l'interface.
///
/// Le message est toujours redige en francais afin d'alimenter directement les
/// snackbars. La structure correspond au format d'erreur du backend :
/// `{"error": {"status", "code", "message", "fields"}}`.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.fields = const {},
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic> fields;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 400;

  /// Extrait un message lisible depuis l'objet `fields` (erreurs de validation).
  String? firstFieldError() {
    for (final value in fields.values) {
      if (value is String && value.isNotEmpty) return value;
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.isNotEmpty) return first;
      }
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
