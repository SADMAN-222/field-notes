import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/injection.dart' as di;
import '../../core/database/database.dart';
import '../../core/database/daos/customer_dao.dart';
import '../../core/database/daos/field_notes_dao.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/sync_indicator.dart';
import 'site_repository.dart';

class SiteDetailsScreen extends StatelessWidget {
  final String siteId;

  const SiteDetailsScreen({super.key, required this.siteId});

  @override
  Widget build(BuildContext context) {
    final siteRepo = di.sl<SiteRepository>();
    final customerDao = di.sl<CustomerDao>();
    final fieldNotesDao = di.sl<FieldNotesDao>();

    return StreamBuilder<Site?>(
      stream: siteRepo.watchSiteById(siteId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Site Load Error')),
            body: Center(child: Text('Could not load site: ${snapshot.error}')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final site = snapshot.data;
        if (site == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Site Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Site does not exist or has been removed.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(site.siteName),
            actions: [
              const SyncIndicator(),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Site',
                onPressed: () => context.push('/sites/${site.id}/edit'),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.syncError,
                ),
                tooltip: 'Delete Site',
                onPressed: () => _confirmDelete(context, site, siteRepo),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Site Info Card
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_city_outlined,
                              color: AppColors.secondary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  site.siteName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FutureBuilder<Customer?>(
                                  future: customerDao.getCustomerById(
                                    site.customerId,
                                  ),
                                  builder: (context, custSnap) {
                                    final customer = custSnap.data;
                                    if (customer == null) {
                                      return const Text(
                                        'Customer',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      );
                                    }
                                    return InkWell(
                                      onTap: () => context.push(
                                        '/customers/${customer.id}',
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.business_outlined,
                                            size: 13,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            customer.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (site.address != null &&
                          site.address!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text(
                          'Address & Location',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          site.address!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Field Notes Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Field Notes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          context.push('/notes/new?siteId=${site.id}'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Note'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Notes Stream
                StreamBuilder<List<FieldNote>>(
                  stream: fieldNotesDao.watchNotesBySite(site.id),
                  builder: (context, noteSnapshot) {
                    if (noteSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final notes = noteSnapshot.data ?? [];
                    if (notes.isEmpty) {
                      return AppCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.assignment_outlined,
                              size: 36,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No Field Notes Recorded',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Record site surveys, maintenance logs, and inspection photos.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () =>
                                  context.push('/notes/new?siteId=${site.id}'),
                              child: const Text('Record First Note'),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: notes.map((note) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            onTap: () => context.push('/notes/${note.id}'),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Icon(
                                    note.photoPath != null
                                        ? Icons.photo_outlined
                                        : Icons.description_outlined,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        note.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            _formatDate(note.recordedAt),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          if (note.lat != null &&
                                              note.lng != null) ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.location_on_outlined,
                                              size: 12,
                                              color: AppColors.textMuted,
                                            ),
                                            const Text(
                                              ' GPS',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(status: note.status),
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
      },
    );
  }

  void _confirmDelete(BuildContext context, Site site, SiteRepository repo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Site?'),
        content: Text(
          'Are you sure you want to delete "${site.siteName}"? All notes under this site will remain in history or can be reassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.syncError),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await repo.deleteSite(site);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Site "${site.siteName}" deleted.'),
                      backgroundColor: AppColors.syncError,
                    ),
                  );
                  context.pop();
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not delete site: $error')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
