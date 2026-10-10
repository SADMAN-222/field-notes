import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _defaultStatus = 'PENDING';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultStatus = prefs.getString('default_note_status') ?? 'PENDING';
    });
  }

  Future<void> _saveSettings(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_note_status', status);
    setState(() {
      _defaultStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Default Note Status'),
            trailing: DropdownButton<String>(
              value: _defaultStatus,
              items: ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) _saveSettings(val);
              }
            ),
          )
        ],
      )
    );
  }
}

