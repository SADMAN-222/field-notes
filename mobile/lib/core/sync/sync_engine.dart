import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/database.dart';
import '../database/daos/outbox_dao.dart';
import '../security/secure_storage.dart';
import '../storage/preferences_service.dart';

class SyncEngine {
  final AppDatabase db;
  final Dio dio;
  final SecureStorage secureStorage;
  final PreferencesService preferencesService;
  final OutboxDao outboxDao;

  bool _isSyncing = false;
  String? _lastError;
  final _syncStatusController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String?>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicTimer;

  SyncEngine({
    required this.db,
    required this.dio,
    required this.secureStorage,
    required this.preferencesService,
    required this.outboxDao,
  });

  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  Stream<bool> get isSyncingStream => _syncStatusController.stream;
  Stream<String?> get errorStream => _errorController.stream;

  void initialize() {
    _startConnectivityListener();
    _startPeriodicTimer();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicTimer?.cancel();
    _syncStatusController.close();
    _errorController.close();
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && preferencesService.autoSync) {
        retryFailed();
      }
    });
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    final interval = Duration(
      seconds: preferencesService.syncIntervalSeconds.clamp(15, 300),
    );
    _periodicTimer = Timer.periodic(interval, (_) {
      if (preferencesService.autoSync && !_isSyncing) {
        sync();
      }
    });
  }

  void restartPeriodicTimer() {
    _startPeriodicTimer();
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncStatusController.add(true);
    _lastError = null;
    _errorController.add(null);

    try {
      final token = await secureStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw StateError(
          'No authenticated access token available for synchronization.',
        );
      }
      await push();
      await pull();
      await preferencesService.setLastSyncTime(DateTime.now());
    } catch (e) {
      _lastError = _describeError(e);
      _errorController.add(_lastError);
    } finally {
      _isSyncing = false;
      _syncStatusController.add(false);
    }
  }

  Future<void> push() async {
    final currentUserId = await secureStorage.getUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      throw StateError('No authenticated user available for synchronization.');
    }
    final pendingEntries = await outboxDao.getPendingEntries(currentUserId);
    if (pendingEntries.isEmpty) return;

    final customerList = <Map<String, dynamic>>[];
    final siteList = <Map<String, dynamic>>[];
    final noteList = <Map<String, dynamic>>[];
    final photoUploads = <({int outboxId, String noteId, String path})>[];
    final processedIds = <int>[];

    for (final entry in pendingEntries) {
      try {
        if (entry.payload == null) {
          await outboxDao.markFailed(
            entry.id,
            currentUserId,
            'Outbox entry has no payload.',
          );
          continue;
        }
        final payload = jsonDecode(entry.payload!) as Map<String, dynamic>;
        if (payload['userId'] != currentUserId) {
          await outboxDao.markFailed(
            entry.id,
            currentUserId,
            'Outbox entry user does not match the authenticated user.',
          );
          continue;
        }

        if (entry.entityType == 'customer') {
          customerList.add({
            'id': payload['id'],
            'name': payload['name'],
            'contactInformation': payload['contactInformation'],
            'createdAt': payload['createdAt'],
            'updatedAt': payload['updatedAt'],
            'deletedAt': payload['deletedAt'],
            'version': payload['version'] ?? 0,
          });
          processedIds.add(entry.id);
        } else if (entry.entityType == 'site') {
          siteList.add({
            'id': payload['id'],
            'customer': {'id': payload['customerId']},
            'siteName': payload['siteName'],
            'address': payload['address'],
            'createdAt': payload['createdAt'],
            'updatedAt': payload['updatedAt'],
            'deletedAt': payload['deletedAt'],
            'version': payload['version'] ?? 0,
          });
          processedIds.add(entry.id);
        } else if (entry.entityType == 'note') {
          final photoPath = payload['photoPath'] as String?;
          noteList.add({
            'id': payload['id'],
            'site': {'id': payload['siteId']},
            'title': payload['title'],
            'description': payload['description'],
            'status': payload['status'] ?? 'PENDING',
            'lat': payload['lat'],
            'lng': payload['lng'],
            'recordedAt': payload['recordedAt'],
            'photoPath': photoPath != null ? p.basename(photoPath) : null,
            'createdAt': payload['createdAt'],
            'updatedAt': payload['updatedAt'],
            'deletedAt': payload['deletedAt'],
            'version': payload['version'] ?? 0,
          });
          processedIds.add(entry.id);
        } else if (entry.entityType == 'photo') {
          final noteId = payload['noteId'] as String?;
          final photoPath = payload['photoPath'] as String?;
          if (noteId == null || photoPath == null || photoPath.isEmpty) {
            await outboxDao.markFailed(
              entry.id,
              currentUserId,
              'Photo outbox entry is missing the note ID or local path.',
            );
            continue;
          }
          photoUploads.add((
            outboxId: entry.id,
            noteId: noteId,
            path: photoPath,
          ));
        } else {
          await outboxDao.markFailed(
            entry.id,
            currentUserId,
            'Unsupported outbox entity type: ${entry.entityType}.',
          );
        }
      } catch (err) {
        await outboxDao.markFailed(
          entry.id,
          currentUserId,
          _describeError(err),
        );
      }
    }

    if (customerList.isNotEmpty || siteList.isNotEmpty || noteList.isNotEmpty) {
      try {
        final pushPayload = {
          'customers': customerList,
          'sites': siteList,
          'fieldNotes': noteList,
        };

        final response = await dio.post('/api/v1/sync/push', data: pushPayload);

        if (response.statusCode == 200 || response.statusCode == 204) {
          await outboxDao.removeEntries(processedIds, currentUserId);
        } else {
          for (final id in processedIds) {
            await outboxDao.markFailed(
              id,
              currentUserId,
              'Server returned status ${response.statusCode}',
            );
          }
        }
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 409) {
          final body = e.response?.data;
          final conflictDetails = jsonEncode(
            body is Map<String, dynamic>
                ? body
                : {'code': 'SYNC_CONFLICT', 'message': body?.toString()},
          );
          final conflictKeys = <String>{};
          if (body is Map && body['conflicts'] is List) {
            for (final conflict in body['conflicts'] as List) {
              if (conflict is Map &&
                  conflict['entityType'] != null &&
                  conflict['entityId'] != null) {
                conflictKeys.add(
                  '${conflict['entityType']}:${conflict['entityId']}',
                );
              }
            }
          }
          for (final id in processedIds) {
            final entry = pendingEntries.firstWhere(
              (candidate) => candidate.id == id,
            );
            final payload = jsonDecode(entry.payload!) as Map<String, dynamic>;
            final key = '${entry.entityType}:${payload['id']}';
            if (conflictKeys.contains(key)) {
              await outboxDao.markConflict(id, currentUserId, conflictDetails);
            } else {
              await outboxDao.markFailed(
                id,
                currentUserId,
                'The batch was rejected because another record has a sync conflict.',
              );
            }
          }
          throw StateError(
            'Synchronization conflict detected. Local edits were retained; resolve the conflict before retrying.',
          );
        }
        for (final id in processedIds) {
          await outboxDao.markFailed(id, currentUserId, _describeError(e));
        }
        rethrow;
      }
    }

    for (final upload in photoUploads) {
      try {
        final file = File(upload.path);
        if (!await file.exists()) {
          throw FileSystemException('Photo file does not exist.', upload.path);
        }
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            file.path,
            filename: p.basename(file.path),
          ),
        });
        final response = await dio.post(
          '/api/v1/notes/${upload.noteId}/photo',
          data: formData,
        );
        if (response.statusCode == 200 || response.statusCode == 204) {
          await outboxDao.removeEntries([upload.outboxId], currentUserId);
        } else {
          await outboxDao.markFailed(
            upload.outboxId,
            currentUserId,
            'Photo upload returned status ${response.statusCode}.',
          );
        }
      } catch (error) {
        await outboxDao.markFailed(
          upload.outboxId,
          currentUserId,
          _describeError(error),
        );
        rethrow;
      }
    }
  }

  Future<void> pull() async {
    final currentUserId = await secureStorage.getUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      throw StateError('No authenticated user available for synchronization.');
    }
    final cursor = await _getCursor(currentUserId);
    final queryParams = <String, dynamic>{};
    if (cursor.isNotEmpty && cursor != '1970-01-01T00:00:00Z') {
      queryParams['cursor'] = cursor;
    }

    final response = await dio.get(
      '/api/v1/sync/pull',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final nextCursor = data['nextCursor']?.toString();
      await db.transaction(() async {
        // 1. Process Customers
        if (data['customers'] is List) {
          for (final c in data['customers']) {
            await db
                .into(db.customers)
                .insertOnConflictUpdate(
                  CustomersCompanion.insert(
                    id: c['id'].toString(),
                    userId: currentUserId,
                    name: c['name']?.toString() ?? '',
                    contactInformation: Value(
                      c['contactInformation']?.toString(),
                    ),
                    createdAt: DateTime.parse(c['createdAt']),
                    updatedAt: DateTime.parse(c['updatedAt']),
                    deletedAt: Value(
                      c['deletedAt'] != null
                          ? DateTime.parse(c['deletedAt'])
                          : null,
                    ),
                    version: Value((c['version'] as num?)?.toInt() ?? 0),
                  ),
                );
          }
        }

        // 2. Process Deleted Customer IDs
        if (data['deletedCustomerIds'] is List) {
          for (final id in data['deletedCustomerIds']) {
            await (db.update(db.customers)..where(
                  (t) =>
                      t.id.equals(id.toString()) &
                      t.userId.equals(currentUserId),
                ))
                .write(CustomersCompanion(deletedAt: Value(DateTime.now())));
          }
        }

        // 3. Process Sites
        if (data['sites'] is List) {
          for (final s in data['sites']) {
            final custId =
                s['customerId']?.toString() ??
                (s['customer'] != null
                    ? s['customer']['id']?.toString()
                    : null);
            if (custId != null) {
              await db
                  .into(db.sites)
                  .insertOnConflictUpdate(
                    SitesCompanion.insert(
                      id: s['id'].toString(),
                      userId: currentUserId,
                      customerId: custId,
                      siteName: s['siteName']?.toString() ?? '',
                      address: Value(s['address']?.toString()),
                      createdAt: DateTime.parse(s['createdAt']),
                      updatedAt: DateTime.parse(s['updatedAt']),
                      deletedAt: Value(
                        s['deletedAt'] != null
                            ? DateTime.parse(s['deletedAt'])
                            : null,
                      ),
                      version: Value((s['version'] as num?)?.toInt() ?? 0),
                    ),
                  );
            }
          }
        }

        // 4. Process Deleted Site IDs
        if (data['deletedSiteIds'] is List) {
          for (final id in data['deletedSiteIds']) {
            await (db.update(db.sites)..where(
                  (t) =>
                      t.id.equals(id.toString()) &
                      t.userId.equals(currentUserId),
                ))
                .write(SitesCompanion(deletedAt: Value(DateTime.now())));
          }
        }

        // 5. Process Field Notes
        if (data['fieldNotes'] is List) {
          for (final fn in data['fieldNotes']) {
            final siteId =
                fn['siteId']?.toString() ??
                (fn['site'] != null ? fn['site']['id']?.toString() : null);
            if (siteId != null) {
              await db
                  .into(db.fieldNotes)
                  .insertOnConflictUpdate(
                    FieldNotesCompanion.insert(
                      id: fn['id'].toString(),
                      userId: currentUserId,
                      siteId: siteId,
                      title: fn['title']?.toString() ?? '',
                      description: Value(fn['description']?.toString()),
                      status: fn['status']?.toString() ?? 'PENDING',
                      lat: Value((fn['lat'] as num?)?.toDouble()),
                      lng: Value((fn['lng'] as num?)?.toDouble()),
                      recordedAt: fn['recordedAt'] != null
                          ? DateTime.parse(fn['recordedAt'])
                          : DateTime.now(),
                      photoPath: Value(fn['photoPath']?.toString()),
                      createdAt: DateTime.parse(fn['createdAt']),
                      updatedAt: DateTime.parse(fn['updatedAt']),
                      deletedAt: Value(
                        fn['deletedAt'] != null
                            ? DateTime.parse(fn['deletedAt'])
                            : null,
                      ),
                      version: Value((fn['version'] as num?)?.toInt() ?? 0),
                    ),
                  );
            }
          }
        }

        // 6. Process Deleted Note IDs
        if (data['deletedFieldNoteIds'] is List) {
          for (final id in data['deletedFieldNoteIds']) {
            await (db.update(db.fieldNotes)..where(
                  (t) =>
                      t.id.equals(id.toString()) &
                      t.userId.equals(currentUserId),
                ))
                .write(FieldNotesCompanion(deletedAt: Value(DateTime.now())));
          }
        }
      });
      if (data['fieldNotes'] is List) {
        for (final note in data['fieldNotes'] as List) {
          if (note is Map && note['photoPath'] != null) {
            await _downloadPulledPhoto(
              note['id'].toString(),
              note['photoPath'].toString(),
              currentUserId,
            );
          }
        }
      }
      if (nextCursor != null && nextCursor.isNotEmpty) {
        await _saveCursor(nextCursor, currentUserId);
      }
    }
  }

  Future<void> _downloadPulledPhoto(
    String noteId,
    String storagePath,
    String userId,
  ) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'photos', userId));
    await directory.create(recursive: true);
    final extension = p.extension(storagePath).isEmpty
        ? '.jpg'
        : p.extension(storagePath);
    final target = File(p.join(directory.path, '$noteId$extension'));
    if (!await target.exists()) {
      final response = await dio.get<List<int>>(
        '/api/v1/notes/$noteId/photo',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError(
          'The server returned an empty photo for note $noteId.',
        );
      }
      await target.writeAsBytes(bytes, flush: true);
    }
    await (db.update(
          db.fieldNotes,
        )..where((note) => note.id.equals(noteId) & note.userId.equals(userId)))
        .write(FieldNotesCompanion(photoPath: Value(target.path)));
  }

  Future<void> retryFailed() async {
    final userId = await secureStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('No authenticated user available for synchronization.');
    }
    await outboxDao.retryAllFailed(userId);
    await sync();
  }

  Future<String> _getCursor(String userId) async {
    final entry = await (db.select(
      db.syncMetadata,
    )..where((t) => t.id.equals('cursor:$userId'))).getSingleOrNull();
    return entry?.value ?? '1970-01-01T00:00:00Z';
  }

  Future<void> _saveCursor(String cursor, String userId) async {
    await db
        .into(db.syncMetadata)
        .insertOnConflictUpdate(
          SyncMetadataCompanion.insert(
            id: 'cursor:$userId',
            value: Value(cursor),
          ),
        );
  }

  String _describeError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final body = error.response?.data;
      return [
        if (status != null) 'HTTP $status',
        if (body != null) body.toString(),
        if (error.message != null) error.message!,
        if (status == null && body == null && error.message == null)
          error.toString(),
      ].join(': ');
    }
    return error.toString();
  }
}
