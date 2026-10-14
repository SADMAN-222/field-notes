import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'sites_dao.g.dart';

@DriftAccessor(tables: [Sites, SyncOutbox])
class SitesDao extends DatabaseAccessor<AppDatabase> with _$SitesDaoMixin {
  SitesDao(super.db);

  Stream<List<Site>> watchSitesByCustomer(String customerId, String userId) {
    return (select(sites)
          ..where(
            (tbl) =>
                tbl.customerId.equals(customerId) &
                tbl.userId.equals(userId) &
                tbl.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.siteName)]))
        .watch();
  }

  Future<List<Site>> getSitesByCustomer(String customerId, String userId) {
    return (select(sites)
          ..where(
            (tbl) =>
                tbl.customerId.equals(customerId) &
                tbl.userId.equals(userId) &
                tbl.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.siteName)]))
        .get();
  }

  Stream<List<Site>> watchAllSites(String userId) {
    return (select(sites)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.siteName)]))
        .watch();
  }

  Future<List<Site>> getAllSites(String userId) {
    return (select(sites)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.siteName)]))
        .get();
  }

  Future<Site?> getSiteById(String id, String userId) {
    return (select(sites)
          ..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
        .getSingleOrNull();
  }

  Stream<Site?> watchSiteById(String id, String userId) {
    return (select(sites)
          ..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
        .watchSingleOrNull();
  }

  Stream<List<Site>> searchSites(String userId, String query, {String? customerId}) {
    final lowerQuery = '%${query.toLowerCase()}%';
    return (select(sites)
          ..where((tbl) {
            final matchesUser = tbl.userId.equals(userId);
            final notDeleted = tbl.deletedAt.isNull();
            final matchesQuery = tbl.siteName.lower().like(lowerQuery) |
                tbl.address.lower().like(lowerQuery);
            if (customerId != null) {
              return matchesUser & notDeleted & matchesQuery & tbl.customerId.equals(customerId);
            }
            return matchesUser & notDeleted & matchesQuery;
          })
          ..orderBy([(t) => OrderingTerm.asc(t.siteName)]))
        .watch();
  }

  Future<int> getSiteCount(String userId) async {
    final countExp = sites.id.count();
    final query = selectOnly(sites)
      ..where(sites.userId.equals(userId) & sites.deletedAt.isNull())
      ..addColumns([countExp]);
    return await query.map((row) => row.read(countExp)).getSingle() ?? 0;
  }

  Stream<int> watchSiteCount(String userId) {
    final countExp = sites.id.count();
    final query = selectOnly(sites)
      ..where(sites.userId.equals(userId) & sites.deletedAt.isNull())
      ..addColumns([countExp]);
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  Future<void> createSite(Site site) {
    return transaction(() async {
      await into(sites).insert(site);
      final payload = jsonEncode({
        'id': site.id,
        'userId': site.userId,
        'customerId': site.customerId,
        'siteName': site.siteName,
        'address': site.address,
        'createdAt': site.createdAt.toIso8601String(),
        'updatedAt': site.updatedAt.toIso8601String(),
        'deletedAt': site.deletedAt?.toIso8601String(),
        'version': site.version,
      });

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'site',
        entityId: site.id,
        operation: 'CREATE',
        payload: Value(payload),
        expectedVersion: Value(0),
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> updateSite(Site site) {
    return transaction(() async {
      final updated = await (update(sites)
            ..where(
              (tbl) => tbl.id.equals(site.id) & tbl.userId.equals(site.userId),
            ))
          .write(site.toCompanion(true));
      if (updated != 1) {
        throw StateError('Site does not belong to the active account.');
      }
      final payload = jsonEncode({
        'id': site.id,
        'userId': site.userId,
        'customerId': site.customerId,
        'siteName': site.siteName,
        'address': site.address,
        'createdAt': site.createdAt.toIso8601String(),
        'updatedAt': site.updatedAt.toIso8601String(),
        'deletedAt': site.deletedAt?.toIso8601String(),
        'version': site.version,
      });

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'site',
        entityId: site.id,
        operation: 'UPDATE',
        payload: Value(payload),
        expectedVersion: Value(site.version),
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> deleteSite(Site site) {
    return transaction(() async {
      final deletedSite = site.copyWith(deletedAt: Value(DateTime.now()));
      final updated = await (update(sites)
            ..where(
              (tbl) => tbl.id.equals(site.id) & tbl.userId.equals(site.userId),
            ))
          .write(SitesCompanion(deletedAt: Value(deletedSite.deletedAt)));
      if (updated != 1) {
        throw StateError('Site does not belong to the active account.');
      }

      final payload = jsonEncode({
        'id': site.id,
        'userId': site.userId,
        'customerId': site.customerId,
        'siteName': site.siteName,
        'address': site.address,
        'createdAt': site.createdAt.toIso8601String(),
        'updatedAt': site.updatedAt.toIso8601String(),
        'deletedAt': deletedSite.deletedAt?.toIso8601String(),
        'version': site.version,
      });

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'site',
        entityId: site.id,
        operation: 'DELETE',
        payload: Value(payload),
        expectedVersion: Value(site.version),
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> upsertFromServer(Site site) async {
    await into(sites).insertOnConflictUpdate(site);
  }

  Future<void> deleteFromServer(String siteId, String userId) async {
    await (update(sites)
          ..where((t) => t.id.equals(siteId) & t.userId.equals(userId)))
        .write(SitesCompanion(deletedAt: Value(DateTime.now())));
  }
}
