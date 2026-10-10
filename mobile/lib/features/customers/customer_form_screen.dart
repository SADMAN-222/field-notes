import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/injection.dart' as di;
import 'customer_repository.dart';
import '../../core/database/database.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});
  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Customer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _contactController, decoration: const InputDecoration(labelText: 'Contact Information')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final repo = di.sl<CustomerRepository>();
                await repo.addCustomer(Customer(
                  id: const Uuid().v4(),
                  userId: 'temp_user',
                  name: _nameController.text,
                  contactInformation: _contactController.text,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  version: 0,
                ));
                if (context.mounted) context.pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

