import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/config/injection.dart' as di;
import '../../core/database/daos/customer_dao.dart';
import '../../core/database/daos/sites_dao.dart';
import '../../core/database/daos/field_notes_dao.dart';
import '../../core/database/daos/outbox_dao.dart';
import '../../core/storage/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../authentication/auth_cubit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _baseUrlController = TextEditingController();
  late PreferencesService _prefs;

  bool _autoSync = true;
  int _syncInterval = 30;
  String _defaultStatus = 'DRAFT';
  bool _isTestingConnection = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _prefs = di.sl<PreferencesService>();
    _baseUrlController.text = _prefs.baseUrl;
    _autoSync = _prefs.autoSync;
    _syncInterval = _prefs.syncIntervalSeconds;
    _defaultStatus = _prefs.defaultNoteStatus;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveBaseUrl() async {
    final url = _baseUrlController.text.trim();
    if (url.isNotEmpty) {
      await _prefs.setBaseUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server URL updated.'), backgroundColor: AppColors.primary),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _testResult = null;
    });

    final dio = Dio(BaseOptions(
      baseUrl: _baseUrlController.text.trim(),
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));

    try {
      final response = await dio.get('/actuator/health');
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testSuccess = response.statusCode == 200;
          _testResult = 'Connection successful! (HTTP ${response.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testSuccess = false;
          _testResult = 'Connection failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final outboxDao = di.sl<OutboxDao>();
    final pending = await outboxDao.getPendingEntries();

    if (!mounted) return;

    if (pending.isNotEmpty) {
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.syncWarning),
              SizedBox(width: 8),
              Text('Unsynced Changes'),
            ],
          ),
          content: Text(
            'You have ${pending.length} unsynced operations queued offline on this device. Logging out now will not delete them, but they cannot synchronize until you sign in again.\n\nDo you want to proceed with sign out?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.syncError),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sign Out Anyway'),
            ),
          ],
        ),
      );

      if (shouldLogout != true) return;
    }

    if (mounted) {
      await context.read<AuthCubit>().logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.watch<AuthCubit>();
    final userId = authCubit.currentUserId ?? '';
    final userEmail = authCubit.currentEmail ?? 'User';

    final customerDao = di.sl<CustomerDao>();
    final sitesDao = di.sl<SitesDao>();
    final fieldNotesDao = di.sl<FieldNotesDao>();
    final outboxDao = di.sl<OutboxDao>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Profile Section
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userEmail,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Active Session',
                          style: TextStyle(color: AppColors.syncSynced, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Server Configuration
            const Text(
              'Backend API Server',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _baseUrlController,
                    decoration: InputDecoration(
                      labelText: 'Server Base URL',
                      hintText: 'http://10.0.2.2:8080',
                      prefixIcon: const Icon(Icons.dns_outlined, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, color: AppColors.primary),
                        tooltip: 'Save URL',
                        onPressed: _saveBaseUrl,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTestingConnection ? null : _testConnection,
                          icon: _isTestingConnection
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.network_check, size: 18),
                          label: const Text('Test Connection'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saveBaseUrl,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(80, 48)),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _testSuccess
                            ? AppColors.syncSynced.withValues(alpha: 0.1)
                            : AppColors.syncError.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testSuccess ? AppColors.syncSynced : AppColors.syncError,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sync Preferences
            const Text(
              'Synchronization & Storage',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Sync on Connectivity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Trigger push/pull automatically when device comes online', style: TextStyle(fontSize: 12)),
                    value: _autoSync,
                    onChanged: (val) async {
                      setState(() => _autoSync = val);
                      await _prefs.setAutoSync(val);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Periodic Sync Interval', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Background synchronization frequency', style: TextStyle(fontSize: 12)),
                    trailing: DropdownButton<int>(
                      value: _syncInterval,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 sec')),
                        DropdownMenuItem(value: 30, child: Text('30 sec')),
                        DropdownMenuItem(value: 60, child: Text('1 min')),
                        DropdownMenuItem(value: 300, child: Text('5 min')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _syncInterval = val);
                          await _prefs.setSyncInterval(val);
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Default Note Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Initial status pre-selected on new inspection note', style: TextStyle(fontSize: 12)),
                    trailing: DropdownButton<String>(
                      value: _defaultStatus,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'DRAFT', child: Text('DRAFT')),
                        DropdownMenuItem(value: 'SUBMITTED', child: Text('SUBMITTED')),
                        DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _defaultStatus = val);
                          await _prefs.setDefaultNoteStatus(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Local Database Statistics
            const Text(
              'Device SQLite Statistics',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatRow('Cached Customers', customerDao.getCustomerCount(userId)),
                  const Divider(),
                  _buildStatRow('Cached Sites', sitesDao.getSiteCount(userId)),
                  const Divider(),
                  _buildStatRow('Cached Notes', fieldNotesDao.getNotesCount(userId)),
                  const Divider(),
                  StreamBuilder<int>(
                    stream: outboxDao.watchPendingCount(),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pending Outbox Mutations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: count > 0 ? AppColors.syncPending : AppColors.syncSynced,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, color: AppColors.syncError, size: 18),
              label: const Text('Sign Out of Account', style: TextStyle(color: AppColors.syncError)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.syncError),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, Future<int> countFuture) {
    return FutureBuilder<int>(
      future: countFuture,
      initialData: 0,
      builder: (context, snap) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text('${snap.data ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        );
      },
    );
  }
}
