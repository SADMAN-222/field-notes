import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/injection.dart' as di;
import '../authentication/auth_cubit.dart';
import 'customer_repository.dart';
import '../../core/database/database.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = di.sl<CustomerRepository>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: () => context.push('/sync')),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthCubit>().logout()),
        ],
      ),
      body: StreamBuilder<List<Customer>>(
        // Hardcoded userId for now, it should come from Auth state
        stream: repo.watchCustomers('temp_user'), 
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final customers = snapshot.data!;
          if (customers.isEmpty) return const Center(child: Text('No customers'));
          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final c = customers[index];
              return ListTile(
                title: Text(c.name),
                subtitle: Text(c.contactInformation ?? ''),
                onTap: () => context.push('/customers/\'),
              );
            }
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/customers/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

