import 'package:dio/dio.dart';
import '../../core/security/secure_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/database/database.dart';

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorage secureStorage;
  final AppDatabase db;

  AuthRepository({required this.apiClient, required this.secureStorage, required this.db});

  Future<void> register(String email, String password) async {
    await apiClient.dio.post('/api/v1/auth/register', data: {
      'email': email,
      'password': password,
    });
  }

  Future<void> login(String email, String password) async {
    final response = await apiClient.dio.post('/api/v1/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = response.data;
    await secureStorage.saveTokens(
      accessToken: data['accessToken'],
      refreshToken: data['refreshToken'],
      userId: data['userId'],
    );
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post('/api/v1/auth/logout');
    } catch (_) {}
    await secureStorage.clearAll();
    
    // Clear local database tables!
    await db.transaction(() async {
      await db.delete(db.customers).go();
      await db.delete(db.sites).go();
      await db.delete(db.fieldNotes).go();
      await db.delete(db.syncOutbox).go();
      await db.delete(db.syncMetadata).go();
    });
  }

  Future<bool> isLoggedIn() async {
    final token = await secureStorage.getAccessToken();
    return token != null;
  }
}

