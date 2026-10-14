import 'package:flutter/foundation.dart';
import '../../core/database/database.dart';
import '../../core/database/daos/customer_dao.dart';

class CustomerRepository {
  final CustomerDao customerDao;

  CustomerRepository({required this.customerDao});

  Stream<List<Customer>> watchCustomers(String userId) =>
      customerDao.watchAllCustomers(userId);

  Future<List<Customer>> getAllCustomers(String userId) =>
      customerDao.getAllCustomers(userId);

  Stream<List<Customer>> searchCustomers(String userId, String query) =>
      customerDao.searchCustomers(userId, query);

  Future<Customer?> getCustomerById(String id, String userId) =>
      customerDao.getCustomerById(id, userId);

  Stream<Customer?> watchCustomerById(String id, String userId) =>
      customerDao.watchCustomerById(id, userId);

  Future<int> getCustomerCount(String userId) =>
      customerDao.getCustomerCount(userId);

  Future<void> addCustomer(Customer customer, String userId) {
    if (customer.userId != userId) {
      throw StateError('Customer does not belong to the active account.');
    }
    debugPrint('CustomerRepository.addCustomer: ${customer.userId}, ID: ${customer.id}');
    return customerDao.createCustomer(customer);
  }

  Future<void> updateCustomer(Customer customer, String userId) {
    if (customer.userId != userId) {
      throw StateError('Customer does not belong to the active account.');
    }
    return customerDao.updateCustomer(customer);
  }

  Future<void> deleteCustomer(Customer customer, String userId) {
    if (customer.userId != userId) {
      throw StateError('Customer does not belong to the active account.');
    }
    return customerDao.deleteCustomer(customer);
  }
}
