import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Dio wrapper owning the auth lifecycle:
///  - attaches the bearer token to every request
///  - on 401, performs a single-flight refresh-token rotation and retries once
///  - maps errors to [ApiException] with the backend's message
class ApiClient {
  ApiClient(this._storage, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl + AppConfig.apiPrefix,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      if (options.extra['noAuth'] != true) {
        final token = await _storage.accessToken;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }));
  }

  final Dio _dio;
  final TokenStorage _storage;
  Future<bool>? _refreshing;

  /// Called when a refresh fails — the session is dead. Wired by AuthRepository.
  void Function()? onSessionExpired;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _request(() => _dio.get<Map<String, dynamic>>(path, queryParameters: query));

  /// For endpoints returning a bare JSON array.
  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) =>
      _requestAs<List<dynamic>>(() => _dio.get<List<dynamic>>(path, queryParameters: query))
          .then((v) => v ?? const []);

  Future<Map<String, dynamic>> post(String path, {Object? body, bool noAuth = false}) =>
      _request(() => _dio.post<Map<String, dynamic>>(path,
          data: body, options: Options(extra: {'noAuth': noAuth})));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _request(() => _dio.patch<Map<String, dynamic>>(path, data: body));

  Future<Map<String, dynamic>> delete(String path) =>
      _request(() => _dio.delete<Map<String, dynamic>>(path));

  /// Uploads raw bytes to an absolute, pre-signed URL (e.g. Supabase Storage).
  /// Deliberately unauthenticated: the URL carries its own short-lived token,
  /// and our bearer token must never be sent to a third-party host.
  Future<void> putSigned(
    String absoluteUrl,
    List<int> bytes,
    String contentType, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      await _dio.put<void>(
        absoluteUrl,
        data: Stream.fromIterable([bytes]),
        onSendProgress: onProgress,
        options: Options(
          extra: {'noAuth': true},
          headers: {
            'content-type': contentType,
            Headers.contentLengthHeader: bytes.length,
          },
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Map<String, dynamic>>> Function() send,
  ) =>
      _requestAs<Map<String, dynamic>>(send).then((v) => v ?? const {});

  Future<T?> _requestAs<T>(
    Future<Response<T>> Function() send, {
    bool retried = false,
  }) async {
    try {
      final response = await send();
      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 && !retried && await _storage.refreshToken != null) {
        if (await _refreshSession()) {
          return _requestAs(send, retried: true);
        }
      }
      throw _toApiException(e);
    }
  }

  /// Single-flight: concurrent 401s share one refresh call, because refresh
  /// tokens are single-use on the server (rotation).
  Future<bool> _refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await _storage.refreshToken;
      if (refreshToken == null) return false;
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'noAuth': true}),
      );
      final data = res.data!;
      await _storage.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        user: data['user'] as Map<String, dynamic>,
      );
      return true;
    } on DioException {
      await _storage.clear();
      onSessionExpired?.call();
      return false;
    }
  }

  ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    String message = 'Network error — check your connection';
    String? code;
    if (data is Map<String, dynamic>) {
      final raw = data['message'];
      if (raw is String) message = raw;
      if (raw is List) message = raw.join(', ');
      if (data['details'] is Map<String, dynamic>) {
        final details = (data['details'] as Map<String, dynamic>)
            .values
            .expand((v) => v is List ? v : [v])
            .join(', ');
        if (details.isNotEmpty) message = details;
      }
      code = data['error'] as String?;
    }
    return ApiException(message, statusCode: e.response?.statusCode, code: code);
  }
}
