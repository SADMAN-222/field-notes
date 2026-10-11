import '../../core/security/secure_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/database/database.dart';
import '../../core/storage/preferences_service.dart';

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorage secureStorage;
  final PreferencesService preferencesService;
  final AppDatabase db;

  AuthRepository({
    required this.apiClient,
    required this.secureStorage,
    required this.preferencesService,
    required this.db,
  });

  Future<void> register(String email, String password) async {
    await apiClient.dio.post('/api/v1/auth/register', data: {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<Map<String, String>> login(String email, String password) async {
    final response = await apiClient.dio.post('/api/v1/auth/login', data: {
      'email': email.trim(),
      'password': password,
    });
    final data = response.data as Map<String, dynamic>;
    final accessToken = (data['token'] ?? data['accessToken'] ?? '').toString();
    final refreshToken = (data['refreshToken'] ?? '').toString();
    final userId = (data['id'] ?? data['userId'] ?? '').toString();
    final userEmail = (data['email'] ?? email).toString();

    await secureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      email: userEmail,
    );
    await preferencesService.setUserEmail(userEmail);

    return {'userId': userId, 'email': userEmail};
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post('/api/v1/auth/logout');
    } catch (_) {}
    await secureStorage.clearAll();
    await preferencesService.clearUserPreferences();

    // Clear local database tables safely
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
    return token != null && token.isNotEmpty;
  }

  Future<String?> getUserId() async {
    return await secureStorage.getUserId();
  }

  Future<String?> getUserEmail() async {
    return await secureStorage.getUserEmail() ?? preferencesService.userEmail;
  }
}
