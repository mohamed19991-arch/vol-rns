/// Configuration globale de l'application.
///
/// L'URL de base de l'API est fournie au moment de la compilation via
/// `--dart-define=API_BASE_URL=https://mon-serveur/api`.
/// La valeur par defaut cible l'emulateur Android (10.0.2.2 = machine hote).
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// Timeout des requetes HTTP.
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Taille de page par defaut pour les listes paginees.
  static const int defaultPageSize = 20;
}
