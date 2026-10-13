import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../database/daos/customer_dao.dart';
import '../database/daos/sites_dao.dart';
import '../database/daos/field_notes_dao.dart';
import '../database/daos/outbox_dao.dart';
import '../security/secure_storage.dart';
import '../storage/preferences_service.dart';
import '../network/api_client.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';
import '../sync/sync_engine.dart';
import '../../features/authentication/auth_repository.dart';
import '../../features/customers/customer_repository.dart';
import '../../features/sites/site_repository.dart';
import '../../features/field_notes/field_note_repository.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Storage & Preferences
  final prefs = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(prefs);
  sl.registerSingleton<PreferencesService>(preferencesService);

  final secureStorage = SecureStorage();
  sl.registerSingleton<SecureStorage>(secureStorage);

  // Database & DAOs
  final db = AppDatabase();
  sl.registerSingleton<AppDatabase>(db);
  sl.registerLazySingleton(() => CustomerDao(sl()));
  sl.registerLazySingleton(() => SitesDao(sl()));
  sl.registerLazySingleton(() => FieldNotesDao(sl()));
  sl.registerLazySingleton(() => OutboxDao(sl()));

  // Hardware / System Services
  sl.registerLazySingleton(() => LocationService());
  sl.registerLazySingleton(() => PhotoService());

  // Network & Sync
  sl.registerLazySingleton(
    () => ApiClient(secureStorage: sl(), preferencesService: sl()),
  );

  sl.registerLazySingleton(
    () => SyncEngine(
      db: sl(),
      dio: sl<ApiClient>().dio,
      secureStorage: sl(),
      preferencesService: sl(),
      outboxDao: sl(),
    ),
  );

  // Repositories
  sl.registerLazySingleton(
    () => AuthRepository(
      apiClient: sl(),
      secureStorage: sl(),
      preferencesService: sl(),
    ),
  );
  sl.registerLazySingleton(() => CustomerRepository(customerDao: sl()));
  sl.registerLazySingleton(() => SiteRepository(sitesDao: sl()));
  sl.registerLazySingleton(() => FieldNoteRepository(fieldNotesDao: sl()));
}
