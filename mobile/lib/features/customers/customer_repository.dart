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

  Future<Customer?> getCustomerById(String id) =>
      customerDao.getCustomerById(id);

  Stream<Customer?> watchCustomerById(String id) =>
      customerDao.watchCustomerById(id);

  Future<int> getCustomerCount(String userId) =>
      customerDao.getCustomerCount(userId);

  Future<void> addCustomer(Customer customer) =>
      customerDao.createCustomer(customer);

  Future<void> updateCustomer(Customer customer) =>
      customerDao.updateCustomer(customer);

  Future<void> deleteCustomer(Customer customer) =>
      customerDao.deleteCustomer(customer);
}
