import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/injection.dart' as di;
import '../../core/database/database.dart';
import '../../core/database/daos/customer_dao.dart';
import '../../core/database/daos/sites_dao.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/sync_indicator.dart';
import 'field_note_repository.dart';

class NoteDetailsScreen extends StatelessWidget {
  final String noteId;

  const NoteDetailsScreen({super.key, required this.noteId});

  @override
  Widget build(BuildContext context) {
    final noteRepo = di.sl<FieldNoteRepository>();
    final sitesDao = di.sl<SitesDao>();
    final customerDao = di.sl<CustomerDao>();

    return StreamBuilder<FieldNote?>(
      stream: noteRepo.watchNoteById(noteId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Field Note Load Error')),
            body: Center(
              child: Text('Could not load field note: ${snapshot.error}'),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final note = snapshot.data;
        if (note == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Note Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Field note does not exist or has been removed.'),
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
            title: const Text('Field Note Details'),
            actions: [
              const SyncIndicator(),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Note',
                onPressed: () => context.push('/notes/${note.id}/edit'),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.syncError,
                ),
                tooltip: 'Delete Note',
                onPressed: () => _confirmDelete(context, note, noteRepo),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Primary Header Card
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: note.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Recorded ${_formatDate(note.recordedAt)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Associated Site & Customer
                      FutureBuilder<Site?>(
                        future: sitesDao.getSiteById(note.siteId),
                        builder: (context, siteSnap) {
                          final site = siteSnap.data;
                          if (site == null) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () =>
                                        context.push('/sites/${site.id}'),
                                    child: Text(
                                      site.siteName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              FutureBuilder<Customer?>(
                                future: customerDao.getCustomerById(
                                  site.customerId,
                                ),
                                builder: (context, custSnap) {
                                  final customer = custSnap.data;
                                  if (customer == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Row(
                                    children: [
                                      const Icon(
                                        Icons.business_outlined,
                                        size: 16,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => context.push(
                                          '/customers/${customer.id}',
                                        ),
                                        child: Text(
                                          customer.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Description Card
                if (note.description != null &&
                    note.description!.trim().isNotEmpty) ...[
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Observations & Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          note.description!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Photo Attachment Card
                if (note.photoPath != null && note.photoPath!.isNotEmpty) ...[
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Photo Attachment',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => context.push(
                                '/photo-viewer',
                                extra: note.photoPath!,
                              ),
                              icon: const Icon(Icons.fullscreen, size: 18),
                              label: const Text('Fullscreen'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => context.push(
                            '/photo-viewer',
                            extra: note.photoPath!,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(note.photoPath!),
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 120,
                                  color: AppColors.surfaceSubtle,
                                  child: const Center(
                                    child: Text(
                                      'Photo pending server download or removed locally.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Geolocation Card
                if (note.lat != null && note.lng != null) ...[
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GPS Coordinates',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${note.lat!.toStringAsFixed(6)}, ${note.lng!.toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    'Accurate Device Geotag',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Bar: Quick Status Update
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push('/notes/${note.id}/edit'),
                        child: const Text('Edit Note'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    FieldNote note,
    FieldNoteRepository repo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Field Note?'),
        content: Text(
          'Are you sure you want to delete "${note.title}"? This note and any local photo references will be removed and synchronized.',
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
                await repo.deleteNote(note);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Field note "${note.title}" deleted.'),
                      backgroundColor: AppColors.syncError,
                    ),
                  );
                  context.pop();
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not delete field note: $error'),
                    ),
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
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
