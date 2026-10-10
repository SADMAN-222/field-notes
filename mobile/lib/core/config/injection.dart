import 'package:get_it/get_it.dart';
import '../database/database.dart';
import '../database/daos/customer_dao.dart';
import '../database/daos/sites_dao.dart';
import '../database/daos/field_notes_dao.dart';
import '../security/secure_storage.dart';
import '../network/api_client.dart';
import '../sync/sync_engine.dart';
import '../../features/authentication/auth_repository.dart';
import '../../features/customers/customer_repository.dart';
import '../../features/sites/site_repository.dart';
import '../../features/field_notes/field_note_repository.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // DB
  final db = AppDatabase();
  sl.registerLazySingleton(() => db);
  sl.registerLazySingleton(() => CustomerDao(sl()));
  sl.registerLazySingleton(() => SitesDao(sl()));
  sl.registerLazySingleton(() => FieldNotesDao(sl()));

  // Core
  sl.registerLazySingleton(() => SecureStorage());
  sl.registerLazySingleton(() => ApiClient(baseUrl: 'http://10.0.2.2:8080', secureStorage: sl()));
  sl.registerLazySingleton(() => SyncEngine(db: sl(), dio: sl<ApiClient>().dio, secureStorage: sl()));

  // Repositories
  sl.registerLazySingleton(() => AuthRepository(apiClient: sl(), secureStorage: sl(), db: sl()));
  sl.registerLazySingleton(() => CustomerRepository(customerDao: sl()));
  sl.registerLazySingleton(() => SiteRepository(sitesDao: sl()));
  sl.registerLazySingleton(() => FieldNoteRepository(fieldNotesDao: sl()));
}

