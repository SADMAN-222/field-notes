import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/injection.dart' as di;
import 'site_repository.dart';
import '../../core/database/database.dart';

class SiteFormScreen extends StatefulWidget {
  final String customerId;
  const SiteFormScreen({super.key, required this.customerId});
  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Site')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Site Name')),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final repo = di.sl<SiteRepository>();
                await repo.addSite(Site(
                  id: const Uuid().v4(),
                  userId: 'temp_user',
                  customerId: widget.customerId,
                  siteName: _nameController.text,
                  address: _addressController.text,
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

