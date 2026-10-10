import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/injection.dart' as di;
import 'field_note_repository.dart';
import '../../core/database/database.dart';

class NoteFormScreen extends StatefulWidget {
  final String siteId;
  const NoteFormScreen({super.key, required this.siteId});
  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _status = 'PENDING';

  @override
  void initState() {
    super.initState();
    _loadDefaultStatus();
  }

  Future<void> _loadDefaultStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _status = prefs.getString('default_note_status') ?? 'PENDING';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Field Note')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description')),
            DropdownButton<String>(
              value: _status,
              items: ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              }
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final repo = di.sl<FieldNoteRepository>();
                await repo.addNote(FieldNote(
                  id: const Uuid().v4(),
                  userId: 'temp_user',
                  siteId: widget.siteId,
                  title: _titleController.text,
                  description: _descController.text,
                  status: _status,
                  recordedAt: DateTime.now(),
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

