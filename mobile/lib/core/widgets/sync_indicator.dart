import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/injection.dart';
import '../database/daos/outbox_dao.dart';
import '../sync/sync_engine.dart';
import '../theme/app_colors.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final outboxDao = sl<OutboxDao>();
    final syncEngine = sl<SyncEngine>();

    return StreamBuilder<bool>(
      stream: syncEngine.isSyncingStream,
      initialData: syncEngine.isSyncing,
      builder: (context, syncingSnap) {
        final isSyncing = syncingSnap.data ?? false;

        return StreamBuilder<int>(
          stream: outboxDao.watchPendingCount(),
          initialData: 0,
          builder: (context, pendingSnap) {
            final pendingCount = pendingSnap.data ?? 0;

            Color bgColor;
            Color fgColor;
            String label;
            Widget icon;

            if (isSyncing) {
              bgColor = AppColors.secondary.withValues(alpha: 0.12);
              fgColor = AppColors.secondary;
              label = 'Syncing...';
              icon = SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                ),
              );
            } else if (pendingCount > 0) {
              bgColor = AppColors.syncPending.withValues(alpha: 0.15);
              fgColor = const Color(0xFFB45309); // Dark amber
              label = '$pendingCount pending';
              icon = Icon(Icons.cloud_upload_outlined, size: 14, color: fgColor);
            } else {
              bgColor = AppColors.syncSuccess.withValues(alpha: 0.12);
              fgColor = AppColors.syncSuccess;
              label = 'Synced';
              icon = Icon(Icons.check_circle_outline, size: 14, color: fgColor);
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: InkWell(
                onTap: () => context.push('/sync'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: fgColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

