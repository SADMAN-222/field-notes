import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../security/secure_storage.dart';
import '../storage/preferences_service.dart';

class ApiClient {
  final Dio _dio;
  final SecureStorage _secureStorage;
  final PreferencesService _preferencesService;

  ApiClient({
    required SecureStorage secureStorage,
    required PreferencesService preferencesService,
  })  : _secureStorage = secureStorage,
        _preferencesService = preferencesService,
        _dio = Dio(BaseOptions(
          baseUrl: preferencesService.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ensure dynamic baseUrl if changed in settings
        options.baseUrl = _preferencesService.baseUrl;

        // Try getting token from Supabase session first, then secureStorage
        String? token;
        try {
          token = Supabase.instance.client.auth.currentSession?.accessToken;
        } catch (_) {}
        token ??= await _secureStorage.getAccessToken();

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 && !e.requestOptions.path.contains('/auth/')) {
          // Token expired, attempt Supabase session refresh
          try {
            final res = await Supabase.instance.client.auth.refreshSession();
            final session = res.session;
            if (session != null) {
              final newAccess = session.accessToken;
              await _secureStorage.saveTokens(
                accessToken: newAccess,
                refreshToken: session.refreshToken ?? '',
                userId: session.user.id,
                email: session.user.email ?? '',
              );

              // Retry original request with new token
              final opts = e.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccess';
              final response = await _dio.request(
                opts.path,
                options: Options(
                  method: opts.method,
                  headers: opts.headers,
                  contentType: opts.contentType,
                  responseType: opts.responseType,
                ),
                data: opts.data,
                queryParameters: opts.queryParameters,
              );
              return handler.resolve(response);
            }
          } catch (_) {
            await _secureStorage.clearAll();
          }
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;

  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }
}
