import 'package:supabase_flutter/supabase_flutter.dart';
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

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> register(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
    );
    if (response.session != null) {
      final session = response.session!;
      await _persistSession(session, response.user?.email ?? email.trim());
    }
  }

  Future<Map<String, String>> login(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final session = response.session ?? _supabase.auth.currentSession;
    final user = response.user ?? _supabase.auth.currentUser;
    if (session == null || user == null) {
      throw Exception('Supabase login did not return a valid session.');
    }

    await _persistSession(session, user.email ?? email.trim());
    return {'userId': user.id, 'email': user.email ?? email.trim()};
  }

  Future<void> _persistSession(Session session, String email) async {
    await secureStorage.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      userId: session.user.id,
      email: email,
    );
    await preferencesService.setUserEmail(email);
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
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
    if (_supabase.auth.currentSession != null) {
      return true;
    }
    final token = await secureStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getUserId() async {
    return _supabase.auth.currentUser?.id ?? await secureStorage.getUserId();
  }

  Future<String?> getUserEmail() async {
    return _supabase.auth.currentUser?.email ?? await secureStorage.getUserEmail() ?? preferencesService.userEmail;
  }
}
