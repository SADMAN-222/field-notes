import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'customer_dao.g.dart';

@DriftAccessor(tables: [Customers, SyncOutbox])
class CustomerDao extends DatabaseAccessor<AppDatabase> with _$CustomerDaoMixin {
  CustomerDao(super.db);

  Stream<List<Customer>> watchAllCustomers(String userId) {
    return (select(customers)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<Customer>> getAllCustomers(String userId) {
    return (select(customers)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<Customer?> getCustomerById(String id, String userId) {
    return (select(customers)
          ..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
        .getSingleOrNull();
  }

  Stream<Customer?> watchCustomerById(String id, String userId) {
    return (select(customers)
          ..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
        .watchSingleOrNull();
  }

  Stream<List<Customer>> searchCustomers(String userId, String query) {
    final lowerQuery = '%${query.toLowerCase()}%';
    return (select(customers)
          ..where((tbl) =>
              tbl.userId.equals(userId) &
              tbl.deletedAt.isNull() &
              (tbl.name.lower().like(lowerQuery) |
                  tbl.contactInformation.lower().like(lowerQuery)))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<int> getCustomerCount(String userId) async {
    final countExp = customers.id.count();
    final query = selectOnly(customers)
      ..where(customers.userId.equals(userId) & customers.deletedAt.isNull())
      ..addColumns([countExp]);
    return await query.map((row) => row.read(countExp)).getSingle() ?? 0;
  }

  Stream<int> watchCustomerCount(String userId) {
    final countExp = customers.id.count();
    final query = selectOnly(customers)
      ..where(customers.userId.equals(userId) & customers.deletedAt.isNull())
      ..addColumns([countExp]);
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  Future<void> createCustomer(Customer customer) {
    return transaction(() async {
      await into(customers).insert(customer);

      final payload = jsonEncode({
        'id': customer.id,
        'userId': customer.userId,
        'name': customer.name,
        'contactInformation': customer.contactInformation,
        'createdAt': customer.createdAt.toIso8601String(),
        'updatedAt': customer.updatedAt.toIso8601String(),
        'deletedAt': customer.deletedAt?.toIso8601String(),
        'version': customer.version,
      });

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'customer',
        entityId: customer.id,
        operation: 'CREATE',
        payload: Value(payload),
        expectedVersion: Value(0),
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> updateCustomer(Customer customer) {
    return transaction(() async {
      final updated = await (update(customers)
            ..where(
              (tbl) =>
                  tbl.id.equals(customer.id) &
                  tbl.userId.equals(customer.userId),
            ))
          .write(customer.toCompanion(true));
      if (updated != 1) {
        throw StateError('Customer does not belong to the active account.');
      }

      final payload = jsonEncode({
        'id': customer.id,
        'userId': customer.userId,
        'name': customer.name,
        'contactInformation': customer.contactInformation,
        'createdAt': customer.createdAt.toIso8601String(),
        'updatedAt': customer.updatedAt.toIso8601String(),
        'deletedAt': customer.deletedAt?.toIso8601String(),
        'version': customer.version,
      });

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'customer',
        entityId: customer.id,
        operation: 'UPDATE',
        payload: Value(payload),
        expectedVersion: Value(customer.version),
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> deleteCustomer(Customer customer) {
    return transaction(() async {
      final deletedCustomer = customer.copyWith(
        deletedAt: Value(DateTime.now()),
      );
      final updated = await (update(customers)
            ..where(
              (tbl) =>
                  tbl.id.equals(customer.id) &
                  tbl.userId.equals(customer.userId),
            ))
          .write(CustomersCompanion(deletedAt: Value(deletedCustomer.deletedAt)));
      if (updated != 1) {
        throw StateError('Customer does not belong to the active account.');
      }

      final payload = jsonEncode({
        'id': customer.id,
        'userId': customer.userId,
        'name': customer.name,
        'contactInformation': customer.contactInformation,
        'createdAt': customer.createdAt.toIso8601String(),
        'updatedAt': customer.updatedAt.toIso8601String(),
        'deletedAt': deletedCustomer.deletedAt?.toIso8601String(),
        'version': customer.version,
      });

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'customer',
        entityId: customer.id,
        operation: 'DELETE',
        payload: Value(payload),
        expectedVersion: Value(customer.version),
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> upsertFromServer(Customer customer) async {
    await into(customers).insertOnConflictUpdate(customer);
  }

  Future<void> deleteFromServer(String customerId, String userId) async {
    await (update(customers)
          ..where(
            (t) => t.id.equals(customerId) & t.userId.equals(userId),
          ))
        .write(CustomersCompanion(deletedAt: Value(DateTime.now())));
  }
}
