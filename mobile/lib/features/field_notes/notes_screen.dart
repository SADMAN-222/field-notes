import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/injection.dart' as di;
import 'field_note_repository.dart';
import '../../core/database/database.dart';

class NotesScreen extends StatelessWidget {
  final String siteId;
  const NotesScreen({super.key, required this.siteId});

  @override
  Widget build(BuildContext context) {
    final repo = di.sl<FieldNoteRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Field Notes')),
      body: StreamBuilder<List<FieldNote>>(
        stream: repo.watchNotes(siteId), 
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final notes = snapshot.data!;
          if (notes.isEmpty) return const Center(child: Text('No notes'));
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final n = notes[index];
              return ListTile(
                title: Text(n.title),
                subtitle: Text('\ - \'),
                // onTap: () => context.push('/notes/\'), // Edit not fully implemented in UI
              );
            }
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/sites/\/notes/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

