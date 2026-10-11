import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const _keyBaseUrl = 'pref_base_url';
  static const _keyAutoSync = 'pref_auto_sync';
  static const _keySyncInterval = 'pref_sync_interval';
  static const _keyLastSync = 'pref_last_sync';
  static const _keyUserEmail = 'pref_user_email';

  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  String get baseUrl => _prefs.getString(_keyBaseUrl) ?? defaultBaseUrl;
  Future<void> setBaseUrl(String url) async => await _prefs.setString(_keyBaseUrl, url);

  bool get autoSync => _prefs.getBool(_keyAutoSync) ?? true;
  Future<void> setAutoSync(bool enabled) async => await _prefs.setBool(_keyAutoSync, enabled);

  int get syncIntervalSeconds => _prefs.getInt(_keySyncInterval) ?? 30;
  Future<void> setSyncInterval(int seconds) async => await _prefs.setInt(_keySyncInterval, seconds);

  DateTime? get lastSyncTime {
    final str = _prefs.getString(_keyLastSync);
    return str != null ? DateTime.tryParse(str) : null;
  }
  Future<void> setLastSyncTime(DateTime time) async => await _prefs.setString(_keyLastSync, time.toIso8601String());

  String? get userEmail => _prefs.getString(_keyUserEmail);
  Future<void> setUserEmail(String email) async => await _prefs.setString(_keyUserEmail, email);

  static const _keyDefaultNoteStatus = 'pref_default_note_status';

  String get defaultNoteStatus => _prefs.getString(_keyDefaultNoteStatus) ?? 'DRAFT';
  Future<void> setDefaultNoteStatus(String status) async => await _prefs.setString(_keyDefaultNoteStatus, status);

  Future<void> clearUserPreferences() async {
    await _prefs.remove(_keyLastSync);
    await _prefs.remove(_keyUserEmail);
  }
}
