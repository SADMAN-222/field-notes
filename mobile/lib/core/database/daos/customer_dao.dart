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

  Future<Customer?> getCustomerById(String id) {
    return (select(customers)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Stream<Customer?> watchCustomerById(String id) {
    return (select(customers)..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
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
      await update(customers).replace(customer);

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
      final deletedCustomer = customer.copyWith(deletedAt: Value(DateTime.now()));
      await update(customers).replace(deletedCustomer);

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

  Future<void> deleteFromServer(String customerId) async {
    await (update(customers)..where((t) => t.id.equals(customerId)))
        .write(CustomersCompanion(deletedAt: Value(DateTime.now())));
  }
}
