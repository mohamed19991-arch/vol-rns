import 'package:dio/dio.dart';

import '../../core/api_exception.dart';
import '../../core/config.dart';
import '../services/session_store.dart';

/// Client HTTP central de l'application.
///
/// - Ajoute automatiquement l'en-tete `Authorization: Bearer <access>`.
/// - En cas de 401, tente UN SEUL rafraichissement via `/auth/refresh/` puis
///   rejoue la requete initiale (jamais de boucle infinie).
/// - Si le rafraichissement echoue, notifie l'etat d'authentification pour
///   declencher la deconnexion.
/// - Convertit les erreurs API (format `{"error": {...}}`) en [ApiException]
///   avec un message en francais.
class DioClient {
  DioClient(this._store) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _store.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          final path = error.requestOptions.path;
          final isAuthCall = path.contains('/auth/login/') ||
              path.contains('/auth/refresh/') ||
              path.contains('/auth/password-reset/');

          if (response?.statusCode == 401 && !isAuthCall) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final retried = await _retry(error.requestOptions);
                return handler.resolve(retried);
              } catch (_) {
                // On laisse l'erreur d'origine remonter.
              }
            } else {
              onSessionExpired?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final SessionStore _store;
  late final Dio _dio;

  /// Callback declenche lorsque la session ne peut plus etre rafraichie.
  void Function()? onSessionExpired;

  Dio get dio => _dio;

  Future<bool>? _refreshInFlight;

  Future<bool> _tryRefresh() {
    // Evite les rafraichissements concurrents.
    _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<bool> _performRefresh() async {
    final refresh = await _store.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    try {
      // Dio dedie : n'utilise PAS les intercepteurs pour éviter toute recursion.
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          contentType: Headers.jsonContentType,
        ),
      );
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh/',
        data: {'refresh': refresh},
      );
      final data = response.data;
      final access = data?['access'] as String?;
      if (access == null || access.isEmpty) return false;
      final newRefresh = (data?['refresh'] as String?) ?? refresh;
      await _store.saveTokens(access: access, refresh: newRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await _store.accessToken;
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      options: Options(
        method: requestOptions.method,
        headers: headers,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
      ),
    );
  }

  /// Convertit n'importe quelle erreur en [ApiException] francaise.
  ApiException toApiException(Object error) {
    if (error is ApiException) return error;

    if (error is DioException) {
      final response = error.response;
      final data = response?.data;

      if (data is Map) {
        final rawError = data['error'];
        if (rawError is Map) {
          final status = (rawError['status'] as num?)?.toInt() ??
              response?.statusCode;
          final fieldsRaw = rawError['fields'];
          return ApiException(
            message: (rawError['message'] as String?)?.trim().isNotEmpty == true
                ? rawError['message'] as String
                : _fallbackMessage(status),
            statusCode: status,
            code: rawError['code'] as String?,
            fields: fieldsRaw is Map
                ? Map<String, dynamic>.from(fieldsRaw)
                : const {},
          );
        }
      }

      // Reponse non standard (ex : 500 HTML).
      if (response != null) {
        return ApiException(
          message: _fallbackMessage(response.statusCode),
          statusCode: response.statusCode,
        );
      }

      return ApiException(message: _networkMessage(error));
    }

    return ApiException(message: 'Une erreur inattendue est survenue.');
  }

  String _networkMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Le délai de connexion a expiré. Vérifiez votre réseau.';
      case DioExceptionType.connectionError:
        return 'Impossible de contacter le serveur. Vérifiez votre connexion.';
      case DioExceptionType.cancel:
        return 'La requête a été annulée.';
      default:
        return 'Erreur réseau. Veuillez réessayer.';
    }
  }

  String _fallbackMessage(int? status) {
    switch (status) {
      case 400:
        return 'Les données transmises sont invalides.';
      case 401:
        return 'Session expirée, veuillez vous reconnecter.';
      case 403:
        return "Vous n'avez pas les autorisations nécessaires.";
      case 404:
        return 'Ressource introuvable.';
      case 409:
        return 'Conflit : la donnée existe déjà.';
      case 429:
        return 'Trop de requêtes. Réessayez plus tard.';
      case 500:
      case 502:
      case 503:
        return 'Erreur du serveur. Réessayez plus tard.';
      default:
        return 'Une erreur est survenue.';
    }
  }
}

/// Classe de base des services d'API : fournit la conversion d'erreurs.
abstract class BaseApi {
  BaseApi(this.client);

  final DioClient client;

  Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw client.toApiException(error);
    }
  }
}
