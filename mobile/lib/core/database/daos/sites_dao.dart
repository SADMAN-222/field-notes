import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';
import 'dart:convert';

part 'sites_dao.g.dart';

@DriftAccessor(tables: [Sites, SyncOutbox])
class SitesDao extends DatabaseAccessor<AppDatabase> with _$SitesDaoMixin {
  SitesDao(AppDatabase db) : super(db);

  Stream<List<Site>> watchSitesByCustomer(String customerId) {
    return (select(sites)..where((tbl) => tbl.customerId.equals(customerId) & tbl.deletedAt.isNull())).watch();
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
      await update(sites).replace(site);
      final payload = jsonEncode({
        'id': site.id,
        'userId': site.userId,
        'customerId': site.customerId,
        'siteName': site.siteName,
        'address': site.address,
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
      await update(sites).replace(deletedSite);

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'site',
        entityId: site.id,
        operation: 'DELETE',
        expectedVersion: Value(site.version),
        createdAt: DateTime.now(),
      ));
    });
  }
}

