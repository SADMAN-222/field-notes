import '../../core/database/database.dart';
import '../../core/database/daos/customer_dao.dart';

class CustomerRepository {
  final CustomerDao customerDao;
  
  CustomerRepository({required this.customerDao});

  Stream<List<Customer>> watchCustomers(String userId) => customerDao.watchAllCustomers(userId);
  
  Future<void> addCustomer(Customer customer) => customerDao.createCustomer(customer);
  
  Future<void> updateCustomer(Customer customer) => customerDao.updateCustomer(customer);
  
  Future<void> deleteCustomer(Customer customer) => customerDao.deleteCustomer(customer);
}

