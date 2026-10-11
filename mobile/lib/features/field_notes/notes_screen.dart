import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/injection.dart' as di;
import '../../core/database/database.dart';
import '../../core/database/daos/sites_dao.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/sync_indicator.dart';
import '../authentication/auth_cubit.dart';
import 'field_note_repository.dart';

class NotesScreen extends StatefulWidget {
  final String? siteId;

  const NotesScreen({super.key, this.siteId});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'ALL';

  final List<String> _statusFilters = ['ALL', 'DRAFT', 'SUBMITTED', 'COMPLETED', 'CANCELLED'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.watch<AuthCubit>();
    final userId = authCubit.currentUserId ?? '';
    final noteRepo = di.sl<FieldNoteRepository>();
    final sitesDao = di.sl<SitesDao>();
    final syncEngine = di.sl<SyncEngine>();

    final statusFilter = _selectedStatus == 'ALL' ? null : _selectedStatus;
    final queryFilter = _searchQuery.isEmpty ? null : _searchQuery;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.siteId != null ? 'Site Field Notes' : 'Field Notes'),
        actions: [
          const SyncIndicator(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes by title or notes...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),

          // Status filter chips
          Container(
            color: Colors.white,
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final status = _statusFilters[index];
                final isSelected = _selectedStatus == status;
                return ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceSubtle,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedStatus = status);
                    }
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Notes List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => syncEngine.sync(),
              child: StreamBuilder<List<FieldNote>>(
                stream: noteRepo.watchAllNotes(
                  userId,
                  status: statusFilter,
                  query: queryFilter,
                  siteId: widget.siteId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final notes = snapshot.data ?? [];

                  if (notes.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.assignment_outlined,
                      title: 'No Field Notes Found',
                      subtitle: _searchQuery.isNotEmpty || _selectedStatus != 'ALL'
                          ? 'Try clearing active filters to see all notes.'
                          : 'Create your first field note with photos, GPS, and inspection data.',
                      actionLabel: _searchQuery.isEmpty && _selectedStatus == 'ALL' ? 'Create Note' : null,
                      onAction: _searchQuery.isEmpty && _selectedStatus == 'ALL'
                          ? () => context.push(widget.siteId != null
                              ? '/notes/new?siteId=${widget.siteId}'
                              : '/notes/new')
                          : null,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return AppCard(
                        onTap: () => context.push('/notes/${note.id}'),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail / Icon
                            _buildThumbnail(note.photoPath),
                            const SizedBox(width: 14),
                            // Details
                            Expanded(
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusBadge(status: note.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (note.description != null && note.description!.trim().isNotEmpty) ...[
                                    Text(
                                      note.description!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Row(
                                    children: [
                                      // Site Name
                                      FutureBuilder<Site?>(
                                        future: sitesDao.getSiteById(note.siteId),
                                        builder: (context, siteSnap) {
                                          final siteName = siteSnap.data?.siteName ?? 'Site';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceSubtle,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.location_on_outlined,
                                                    size: 11, color: AppColors.textMuted),
                                                const SizedBox(width: 2),
                                                Text(
                                                  siteName,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      const Spacer(),
                                      // Date & GPS
                                      if (note.lat != null && note.lng != null) ...[
                                        const Icon(Icons.my_location, size: 12, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        _formatDate(note.recordedAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
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
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(widget.siteId != null
            ? '/notes/new?siteId=${widget.siteId}'
            : '/notes/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildThumbnail(String? photoPath) {
    if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _defaultIcon(),
          ),
        );
      }
    }
    return _defaultIcon();
  }

  Widget _defaultIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 22),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
