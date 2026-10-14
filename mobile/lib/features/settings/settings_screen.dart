import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/injection.dart' as di;
import '../../core/database/daos/customer_dao.dart';
import '../../core/database/daos/field_notes_dao.dart';
import '../../core/database/daos/outbox_dao.dart';
import '../../core/database/daos/sites_dao.dart';
import '../../core/database/database.dart';
import '../../core/storage/preferences_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_colors.dart';
import '../authentication/auth_cubit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PreferencesService _prefs;
  late final SyncEngine _syncEngine;
  late final TextEditingController _baseUrlController;
  bool _autoSync = true;
  int _syncInterval = 30;
  String _defaultStatus = 'PENDING';
  bool _isTestingConnection = false;
  bool? _serverConnected;
  String? _connectionMessage;

  @override
  void initState() {
    super.initState();
    _prefs = di.sl<PreferencesService>();
    _syncEngine = di.sl<SyncEngine>();
    _baseUrlController = TextEditingController(text: _prefs.baseUrl);
    _autoSync = _prefs.autoSync;
    _syncInterval = _prefs.syncIntervalSeconds;
    _defaultStatus = _prefs.defaultNoteStatus;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveBaseUrl(String value) async {
    final url = _normalizeBaseUrl(value);
    if (url.isEmpty) return;
    await _prefs.setBaseUrl(url);
    _baseUrlController.text = url;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server configuration saved.')),
      );
    }
  }

  String _normalizeBaseUrl(String value) {
    var url = value.trim().replaceFirst(RegExp(r'/+$'), '');
    if (url.endsWith('/api/v1')) {
      url = url.substring(0, url.length - '/api/v1'.length);
    }
    return url;
  }

  Future<void> _testConnection() async {
    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
    if (baseUrl.isEmpty) {
      setState(() {
        _serverConnected = false;
        _connectionMessage = 'Enter a server URL to test the connection.';
      });
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionMessage = null;
    });

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    try {
      final response = await dio.get('/actuator/health');
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _serverConnected = response.statusCode == 200;
          _connectionMessage = response.statusCode == 200
              ? 'Connection successful'
              : 'Server returned HTTP ${response.statusCode}';
        });
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _serverConnected = false;
          _connectionMessage = error.response == null
              ? error.message ?? 'Unable to reach the server.'
              : 'Server returned HTTP ${error.response?.statusCode}.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _serverConnected = false;
          _connectionMessage = 'Connection test failed: $error';
        });
      }
    }
  }

  Future<void> _syncNow() async {
    if (_syncEngine.isSyncing) return;
    try {
      await _syncEngine.retryFailed();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start synchronization: $error')),
      );
      return;
    }
    if (!mounted) return;
    final error = _syncEngine.lastError;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync needs attention: $error')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Synchronization completed.')),
      );
    }
  }

  Future<void> _handleLogout() async {
    final outboxDao = di.sl<OutboxDao>();
    final userId = context.read<AuthCubit>().currentUserId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active user session.')),
      );
      return;
    }
    final queuedEntries = await _readOutboxEntries(outboxDao, userId);
    if (queuedEntries == null) return;
    if (!mounted) return;

    if (queuedEntries.isNotEmpty) {
      final syncBeforeSignOut = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Unsynced changes'),
          content: Text(
            'You have ${queuedEntries.length} unsynced changes that may not have reached the server yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sync & Sign Out'),
            ),
          ],
        ),
      );
      if (syncBeforeSignOut != true) return;

      try {
        await _syncEngine.retryFailed();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not sync changes. You remain signed in: $error',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
      if (!mounted) return;
      final remaining = await _readOutboxEntries(outboxDao, userId);
      if (!mounted) return;
      if (remaining == null) return;
      if (remaining.isNotEmpty) {
        final detail = _syncEngine.lastError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detail == null
                  ? '${remaining.length} changes are still unsynced. You remain signed in.'
                  : 'Sync failed. You remain signed in: $detail',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
    } else {
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sign out of your account?'),
          content: const Text(
            'Your synced data remains in your account. Local cached data and photos will be removed from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
      if (shouldSignOut != true) return;
    }

    if (!mounted) return;
    final authCubit = context.read<AuthCubit>();
    try {
      await di.sl<AppDatabase>().clearAccountData(userId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not clear local account data: $error')),
        );
      }
      return;
    }
    await authCubit.logout();
    if (mounted) context.go('/login');
  }

  Future<List<SyncOutboxEntry>?> _readOutboxEntries(
    OutboxDao outboxDao,
    String userId,
  ) async {
    try {
      return await outboxDao.watchAllOutbox(userId).first;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not check unsynced changes: $error'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _showServerConfiguration() async {
    final controller = TextEditingController(text: _prefs.baseUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Server configuration'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Backend base URL',
            hintText: 'http://10.0.2.2:8080',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await _saveBaseUrl(value);
  }

  Future<void> _chooseSyncInterval() async {
    final selected = await _chooseOption<int>(
      title: 'Sync interval',
      currentValue: _syncInterval,
      options: const [
        (15, '15 seconds'),
        (30, '30 seconds'),
        (60, '1 minute'),
        (300, '5 minutes'),
      ],
    );
    if (selected == null) return;
    setState(() => _syncInterval = selected);
    await _prefs.setSyncInterval(selected);
    _syncEngine.restartPeriodicTimer();
  }

  Future<void> _chooseDefaultStatus() async {
    final selected = await _chooseOption<String>(
      title: 'Default note status',
      currentValue: _defaultStatus,
      options: const [
        ('PENDING', 'Pending'),
        ('IN_PROGRESS', 'In progress'),
        ('COMPLETED', 'Completed'),
        ('CANCELLED', 'Cancelled'),
      ],
    );
    if (selected == null) return;
    setState(() => _defaultStatus = selected);
    await _prefs.setDefaultNoteStatus(selected);
  }

  Future<T?> _chooseOption<T>({
    required String title,
    required T currentValue,
    required List<(T, String)> options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            RadioGroup<T>(
              groupValue: currentValue,
              onChanged: (selected) => Navigator.of(context).pop(selected),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (value, label) in options)
                    RadioListTile<T>(value: value, title: Text(label)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.watch<AuthCubit>();
    final userId = authCubit.currentUserId ?? '';
    final userEmail = authCubit.currentEmail;
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = _displayName(user?.userMetadata);
    final email = user?.email ?? userEmail;
    final avatarText = _initials(displayName ?? email);
    final customerDao = di.sl<CustomerDao>();
    final sitesDao = di.sl<SitesDao>();
    final fieldNotesDao = di.sl<FieldNotesDao>();
    final outboxDao = di.sl<OutboxDao>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _SectionLabel('ACCOUNT'),
          _AccountHeader(
            displayName: displayName,
            email: email,
            initials: avatarText,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AccountDetailsScreen(
                    user: user,
                    fallbackEmail: userEmail,
                    fallbackUserId: userId,
                    lastSyncTime: _prefs.lastSyncTime,
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 24),
          _SectionLabel('SYNC & DATA'),
          _SettingsGroup(
            children: [
              _SyncStatusRow(
                syncEngine: _syncEngine,
                outboxDao: outboxDao,
                lastSyncTime: _prefs.lastSyncTime,
              ),
              const _GroupDivider(),
              StreamBuilder<bool>(
                stream: _syncEngine.isSyncingStream,
                initialData: _syncEngine.isSyncing,
                builder: (context, snapshot) {
                  final syncing = snapshot.data ?? false;
                  return ListTile(
                    leading: const Icon(Icons.sync_rounded),
                    title: const Text('Sync now'),
                    subtitle: const Text('Send changes and check for updates'),
                    trailing: syncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: syncing ? null : _syncNow,
                  );
                },
              ),
              const _GroupDivider(),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: const Icon(Icons.wifi_rounded),
                title: const Text('Auto-sync on connectivity'),
                subtitle: const Text('Sync when a connection is available'),
                value: _autoSync,
                onChanged: (value) async {
                  setState(() => _autoSync = value);
                  await _prefs.setAutoSync(value);
                },
              ),
              const _GroupDivider(),
              _SettingsValueRow(
                icon: Icons.schedule_rounded,
                title: 'Sync interval',
                value: _formatInterval(_syncInterval),
                onTap: _chooseSyncInterval,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('FIELD NOTES'),
          _SettingsGroup(
            children: [
              _SettingsValueRow(
                icon: Icons.edit_note_rounded,
                title: 'Default note status',
                value:
                    _defaultStatus[0] +
                    _defaultStatus.substring(1).toLowerCase(),
                onTap: _chooseDefaultStatus,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('STORAGE'),
          _SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.storage_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Local data',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              _StatRow(
                label: 'Customers',
                count: customerDao.getCustomerCount(userId),
              ),
              _StatRow(label: 'Sites', count: sitesDao.getSiteCount(userId)),
              _StatRow(
                label: 'Field notes',
                count: fieldNotesDao.getNotesCount(userId),
              ),
              StreamBuilder<List<dynamic>>(
                stream: outboxDao.watchAllOutbox(
                  context.watch<AuthCubit>().currentUserId ?? '',
                ),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return _StatRow(
                    label: 'Pending sync',
                    value: '$count',
                    valueColor: count > 0
                        ? AppColors.syncWarning
                        : AppColors.syncSynced,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('SERVER'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Backend server'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_serverConnected != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _serverConnected!
                                ? Icons.check_circle
                                : Icons.error_outline,
                            size: 15,
                            color: _serverConnected!
                                ? AppColors.syncSynced
                                : AppColors.syncError,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _connectionMessage ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      _apiDisplayUrl(_prefs.baseUrl),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: _showServerConfiguration,
              ),
              const _GroupDivider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Development server configuration',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isTestingConnection ? null : _testConnection,
                      child: _isTestingConnection
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test connection'),
                    ),
                  ],
                ),
              ),
              const _GroupDivider(),
              _SettingsValueRow(
                icon: Icons.settings_outlined,
                title: 'Server configuration',
                value: 'Configure',
                onTap: _showServerConfiguration,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('ACCOUNT ACTIONS'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.syncError),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.syncError),
                ),
                onTap: _handleLogout,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('ABOUT'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.work_outline_rounded),
                title: const Text('Field Notes'),
                subtitle: const Text('Version 1.0.0'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Field Notes',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({
    required this.user,
    required this.fallbackEmail,
    required this.fallbackUserId,
    required this.lastSyncTime,
    super.key,
  });

  final User? user;
  final String? fallbackEmail;
  final String fallbackUserId;
  final DateTime? lastSyncTime;

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  late User? _user = widget.user;
  bool _isSaving = false;

  String? get _name => _displayName(_user?.userMetadata);
  String? get _email => _user?.email ?? widget.fallbackEmail;
  String? get _provider {
    final provider = _user?.appMetadata['provider'];
    return provider is String && provider.trim().isNotEmpty ? provider : null;
  }

  Future<void> _editDisplayName() async {
    final user = _user;
    if (user == null) return;
    final controller = TextEditingController(text: _name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Display name',
            hintText: 'Enter your name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'display_name': name.trim().isEmpty ? null : name.trim()},
        ),
      );
      if (!mounted) return;
      setState(() {
        _user = Supabase.instance.client.auth.currentUser;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;
    final accountId = _user?.id ?? widget.fallbackUserId;
    final initials = _initials(_name ?? email);
    final sessionActive = Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Account details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _name ?? email ?? 'Account',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (_name != null && email != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                email,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SettingsGroup(
            children: [
              if (_user != null)
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Display name'),
                  subtitle: Text(_name ?? 'Not set'),
                  trailing: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_outlined),
                  onTap: _isSaving ? null : _editDisplayName,
                ),
              if (email != null)
                _DetailRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                ),
              if (accountId.isNotEmpty)
                _DetailRow(
                  icon: Icons.fingerprint,
                  label: 'Account ID',
                  value: accountId,
                ),
              if (_provider != null)
                _DetailRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Authentication provider',
                  value: _provider!,
                ),
              _DetailRow(
                icon: Icons.shield_outlined,
                label: 'Account status',
                value: 'Active',
              ),
              _DetailRow(
                icon: Icons.lock_outline,
                label: 'Session status',
                value: sessionActive
                    ? 'Active Supabase session'
                    : 'Signed-in session',
              ),
              if (widget.lastSyncTime != null)
                _DetailRow(
                  icon: Icons.sync_rounded,
                  label: 'Last successful sync',
                  value: _formatTimestamp(widget.lastSyncTime!),
                ),
            ],
          ),
          if (_user == null) ...[
            const SizedBox(height: 12),
            Text(
              'Profile metadata is unavailable for this session.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.displayName,
    required this.email,
    required this.initials,
    required this.onTap,
  });

  final String? displayName;
  final String? email;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName ?? email ?? 'Account',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (displayName != null && email != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        email!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 7),
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 15,
                          color: AppColors.syncSynced,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Active account',
                          style: TextStyle(
                            color: AppColors.syncSynced,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Account details',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusRow extends StatelessWidget {
  const _SyncStatusRow({
    required this.syncEngine,
    required this.outboxDao,
    required this.lastSyncTime,
  });

  final SyncEngine syncEngine;
  final OutboxDao outboxDao;
  final DateTime? lastSyncTime;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: syncEngine.errorStream,
      initialData: syncEngine.lastError,
      builder: (context, errorSnapshot) {
        return StreamBuilder<bool>(
          stream: syncEngine.isSyncingStream,
          initialData: syncEngine.isSyncing,
          builder: (context, syncingSnapshot) {
            return StreamBuilder<List<dynamic>>(
              stream: outboxDao.watchAllOutbox(
                context.watch<AuthCubit>().currentUserId ?? '',
              ),
              builder: (context, outboxSnapshot) {
                final syncing = syncingSnapshot.data ?? false;
                final pendingCount = outboxSnapshot.data?.length ?? 0;
                final error = errorSnapshot.data;
                final (label, detail, color, icon) = _syncStatusPresentation(
                  syncing: syncing,
                  pendingCount: pendingCount,
                  error: error,
                  lastSyncTime: lastSyncTime,
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sync status',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    this.count,
    this.value,
    this.valueColor,
  });

  final String label;
  final Future<int>? count;
  final String? value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    if (value != null) {
      return _StatRowLayout(label: label, value: value!, color: valueColor);
    }
    return FutureBuilder<int>(
      future: count,
      builder: (context, snapshot) => _StatRowLayout(
        label: label,
        value: snapshot.hasError ? '—' : '${snapshot.data ?? 0}',
      ),
    );
  }
}

class _StatRowLayout extends StatelessWidget {
  const _StatRowLayout({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label),
      subtitle: SelectableText(value),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SettingsValueRow extends StatelessWidget {
  const _SettingsValueRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 56, endIndent: 16);
}

String? _displayName(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  for (final key in ['display_name', 'full_name', 'name']) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  final first = metadata['first_name'];
  final last = metadata['last_name'];
  final parts = [
    if (first is String && first.trim().isNotEmpty) first.trim(),
    if (last is String && last.trim().isNotEmpty) last.trim(),
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

String _initials(String? value) {
  if (value == null || value.trim().isEmpty) return 'A';
  final parts = value
      .trim()
      .split(RegExp(r'[\s._@-]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'A';
  if (parts.length > 1) {
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
  final part = parts.first;
  return part.substring(0, part.length > 1 ? 2 : 1).toUpperCase();
}

String _formatInterval(int seconds) {
  if (seconds < 60) return '$seconds sec';
  return '${seconds ~/ 60} min';
}

String _apiDisplayUrl(String baseUrl) {
  final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
  return base.endsWith('/api/v1') ? base : '$base/api/v1';
}

String _formatTimestamp(DateTime time) {
  final localTime = time.toLocal();
  final difference = DateTime.now().difference(localTime);
  if (difference.inSeconds < 60) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  return '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}';
}

(String, String, Color, IconData) _syncStatusPresentation({
  required bool syncing,
  required int pendingCount,
  required String? error,
  required DateTime? lastSyncTime,
}) {
  if (syncing) {
    return (
      'Syncing…',
      pendingCount > 0
          ? 'Processing $pendingCount queued changes'
          : 'Checking for server updates',
      AppColors.primary,
      Icons.sync_rounded,
    );
  }
  if (error != null) {
    return (
      'Needs attention',
      pendingCount > 0
          ? '$pendingCount changes still need to sync'
          : 'The last synchronization failed',
      AppColors.syncError,
      Icons.error_outline,
    );
  }
  if (pendingCount > 0) {
    return (
      'Pending changes',
      '$pendingCount ${pendingCount == 1 ? 'change' : 'changes'} waiting to sync',
      AppColors.syncWarning,
      Icons.pending_actions_rounded,
    );
  }
  if (lastSyncTime != null) {
    return (
      'Synced',
      'Last synced: ${_formatTimestamp(lastSyncTime)}',
      AppColors.syncSynced,
      Icons.check_circle_outline,
    );
  }
  return (
    'Ready to sync',
    'No completed sync yet',
    AppColors.textSecondary,
    Icons.sync_rounded,
  );
}
