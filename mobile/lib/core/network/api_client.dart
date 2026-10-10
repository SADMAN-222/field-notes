import 'package:dio/dio.dart';
import '../security/secure_storage.dart';

class ApiClient {
  final Dio _dio;
  final SecureStorage _secureStorage;

  ApiClient({required String baseUrl, required SecureStorage secureStorage})
      : _secureStorage = secureStorage,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secureStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer \';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token expired, handle refresh
          final refreshToken = await _secureStorage.getRefreshToken();
          if (refreshToken != null) {
            try {
              final refreshResponse = await Dio(BaseOptions(baseUrl: baseUrl)).post(
                '/api/v1/auth/refresh',
                data: {'refreshToken': refreshToken},
              );
              if (refreshResponse.statusCode == 200) {
                final newAccess = refreshResponse.data['accessToken'];
                final newRefresh = refreshResponse.data['refreshToken'];
                final userId = await _secureStorage.getUserId();
                await _secureStorage.saveTokens(accessToken: newAccess, refreshToken: newRefresh, userId: userId!);
                
                // Retry original request
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer \';
                final response = await _dio.request(opts.path,
                    options: Options(
                      method: opts.method,
                      headers: opts.headers,
                    ),
                    data: opts.data,
                    queryParameters: opts.queryParameters);
                return handler.resolve(response);
              }
            } catch (_) {
              // Refresh failed
              await _secureStorage.clearAll();
            }
          }
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}

