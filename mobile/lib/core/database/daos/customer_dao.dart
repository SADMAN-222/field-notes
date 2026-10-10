import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

part 'customer_dao.g.dart';

@DriftAccessor(tables: [Customers, SyncOutbox])
class CustomerDao extends DatabaseAccessor<AppDatabase> with _$CustomerDaoMixin {
  CustomerDao(AppDatabase db) : super(db);

  Stream<List<Customer>> watchAllCustomers(String userId) {
    return (select(customers)..where((tbl) => tbl.userId.equals(userId) & tbl.deletedAt.isNull())).watch();
  }

  Future<void> createCustomer(Customer customer) {
    return transaction(() async {
      await into(customers).insert(customer);
      
      final payload = jsonEncode({
        'id': customer.id,
        'userId': customer.userId,
        'name': customer.name,
        'contactInformation': customer.contactInformation,
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

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        entityType: 'customer',
        entityId: customer.id,
        operation: 'DELETE',
        expectedVersion: Value(customer.version),
        createdAt: DateTime.now(),
      ));
    });
  }
}
