import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/injection.dart' as di;
import '../../core/database/database.dart';
import '../../core/database/daos/outbox_dao.dart';
import '../../core/storage/preferences_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../authentication/auth_cubit.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _manualSyncing = false;

  Future<void> _resolveKeepLocal(SyncOutboxEntry item, String userId) async {
    final keepLocal = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keep this device’s changes?'),
        content: const Text(
          'The server has a newer version. Keeping this device’s version will create a new update based on the current server version and retry synchronization. The server version is not changed unless that retry succeeds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keep Local & Retry'),
          ),
        ],
      ),
    );
    if (keepLocal != true || !mounted) return;
    try {
      await di.sl<OutboxDao>().resolveConflictKeepLocal(item.id, userId);
      await di.sl<SyncEngine>().sync();
      if (!mounted) return;
      final error = di.sl<SyncEngine>().lastError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? 'Local changes synchronized.'
                : 'Local changes remain saved. $error',
          ),
          backgroundColor: error == null
              ? AppColors.syncSuccess
              : AppColors.syncError,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not resolve sync conflict: $error'),
          backgroundColor: AppColors.syncError,
        ),
      );
    }
  }

  Future<void> _triggerSync() async {
    final syncEngine = di.sl<SyncEngine>();
    setState(() => _manualSyncing = true);
    await syncEngine.sync();
    if (mounted) {
      setState(() => _manualSyncing = false);
      final hasError = syncEngine.lastError != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !hasError
                ? 'Synchronization completed successfully.'
                : 'Sync completed with errors: ${syncEngine.lastError}',
          ),
          backgroundColor: !hasError
              ? AppColors.syncSuccess
              : AppColors.syncError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncEngine = di.sl<SyncEngine>();
    final outboxDao = di.sl<OutboxDao>();
    final prefs = di.sl<PreferencesService>();
    final userId = context.watch<AuthCubit>().currentUserId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Synchronization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Now',
            onPressed: _manualSyncing ? null : _triggerSync,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Card
            StreamBuilder<bool>(
              stream: syncEngine.isSyncingStream,
              initialData: syncEngine.isSyncing,
              builder: (context, snapshot) {
                final isSyncing = snapshot.data ?? false;
                final lastSync = prefs.lastSyncTime;

                return AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: isSyncing
                                  ? AppColors.syncPending.withValues(
                                      alpha: 0.15,
                                    )
                                  : AppColors.syncSynced.withValues(
                                      alpha: 0.15,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: isSyncing
                                ? const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.syncPending,
                                            ),
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_done_outlined,
                                    color: AppColors.syncSynced,
                                    size: 26,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSyncing
                                      ? 'Sync In Progress...'
                                      : 'Sync Engine Active',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lastSync != null
                                      ? 'Last synced: ${_formatDate(lastSync)}'
                                      : 'Never synchronized yet',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: isSyncing || _manualSyncing
                            ? null
                            : _triggerSync,
                        icon: const Icon(Icons.sync, size: 18),
                        label: Text(
                          isSyncing || _manualSyncing
                              ? 'Synchronizing...'
                              : 'Sync Now',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Outbox Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Outbox Queue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await outboxDao.retryAllFailed(userId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed items queued for retry.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Retry Failed'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Outbox Items List
            StreamBuilder<List<SyncOutboxEntry>>(
              stream: outboxDao.watchAllOutbox(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return AppCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.syncSynced,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'All Changes Synchronized',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'There are no pending offline mutations queued on this device.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: items.map((item) {
                    final isFailed = item.state == 'FAILED';
                    final isConflict = item.state == 'CONFLICT';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _operationColor(
                                      item.operation,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.operation,
                                    style: TextStyle(
                                      color: _operationColor(item.operation),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.entityType,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isFailed || isConflict
                                        ? AppColors.syncError.withValues(
                                            alpha: 0.1,
                                          )
                                        : AppColors.syncPending.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    item.state,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isFailed || isConflict
                                          ? AppColors.syncError
                                          : AppColors.syncPending,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ID: ${item.entityId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (item.retryCount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Retries: ${item.retryCount}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (item.lastError != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.syncError.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.lastError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.syncError,
                                  ),
                                ),
                              ),
                            ],
                            if (isConflict) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonal(
                                  onPressed: () =>
                                      _resolveKeepLocal(item, userId),
                                  child: const Text('Keep Local & Retry'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _formatDate(item.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _operationColor(String op) {
    switch (op) {
      case 'CREATE':
        return AppColors.syncSynced;
      case 'UPDATE':
        return AppColors.secondary;
      case 'DELETE':
        return AppColors.syncError;
      default:
        return AppColors.textPrimary;
    }
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
