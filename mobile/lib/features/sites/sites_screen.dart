import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/injection.dart' as di;
import 'site_repository.dart';
import '../../core/database/database.dart';

class SitesScreen extends StatelessWidget {
  final String customerId;
  const SitesScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final repo = di.sl<SiteRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sites')),
      body: StreamBuilder<List<Site>>(
        stream: repo.watchSites(customerId), 
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final sites = snapshot.data!;
          if (sites.isEmpty) return const Center(child: Text('No sites'));
          return ListView.builder(
            itemCount: sites.length,
            itemBuilder: (context, index) {
              final s = sites[index];
              return ListTile(
                title: Text(s.siteName),
                subtitle: Text(s.address ?? ''),
                onTap: () => context.push('/sites/\'),
              );
            }
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/customers/\/sites/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

