import 'package:flutter/material.dart';
import '../../core/config/injection.dart' as di;
import '../../core/sync/sync_engine.dart';
import '../../core/database/database.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncEngine = di.sl<SyncEngine>();
    final db = di.sl<AppDatabase>();
    
    return Scaffold(
      appBar: AppBar(title: const Text('Synchronization')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync started...')));
              await syncEngine.sync();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync complete!')));
              }
            },
            child: const Text('Sync Now')
          ),
          Expanded(
            child: StreamBuilder<List<SyncOutboxData>>(
              stream: db.select(db.syncOutbox).watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text('\ \'),
                      subtitle: Text('Status: \ | Error: \'),
                    );
                  }
                );
              }
            )
          )
        ],
      )
    );
  }
}

