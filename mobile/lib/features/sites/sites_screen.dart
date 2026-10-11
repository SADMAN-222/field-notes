import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/injection.dart' as di;
import '../../core/database/database.dart';
import '../../core/database/daos/customer_dao.dart';
import '../../core/database/daos/field_notes_dao.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/sync_indicator.dart';
import '../authentication/auth_cubit.dart';
import 'site_repository.dart';

class SitesScreen extends StatefulWidget {
  final String? customerId;

  const SitesScreen({super.key, this.customerId});

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.watch<AuthCubit>();
    final userId = authCubit.currentUserId ?? '';
    final siteRepo = di.sl<SiteRepository>();
    final customerDao = di.sl<CustomerDao>();
    final fieldNotesDao = di.sl<FieldNotesDao>();
    final syncEngine = di.sl<SyncEngine>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.customerId != null ? 'Customer Sites' : 'All Sites'),
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
          // Search box
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search sites by name or address...',
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
          const Divider(height: 1),

          // Sites list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => syncEngine.sync(),
              child: StreamBuilder<List<Site>>(
                stream: _searchQuery.isEmpty
                    ? (widget.customerId != null
                        ? siteRepo.watchSites(widget.customerId!)
                        : siteRepo.watchAllSites(userId))
                    : siteRepo.searchSites(userId, _searchQuery, customerId: widget.customerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final sites = snapshot.data ?? [];

                  if (sites.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.location_city_outlined,
                      title: _searchQuery.isEmpty ? 'No Sites Found' : 'No Results Found',
                      subtitle: _searchQuery.isEmpty
                          ? 'Register sites to associate field notes and inspections.'
                          : 'Try adjusting your search terms.',
                      actionLabel: _searchQuery.isEmpty ? 'Add Site' : null,
                      onAction: _searchQuery.isEmpty
                          ? () => context.push(widget.customerId != null
                              ? '/sites/new?customerId=${widget.customerId}'
                              : '/sites/new')
                          : null,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sites.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final site = sites[index];
                      return AppCard(
                        onTap: () => context.push('/sites/${site.id}'),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.secondary,
                                size: 22,
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  if (site.address != null && site.address!.trim().isNotEmpty) ...[
                                    Text(
                                      site.address!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                  ],
                                  Row(
                                    children: [
                                      // Customer name badge
                                      FutureBuilder<Customer?>(
                                        future: customerDao.getCustomerById(site.customerId),
                                        builder: (context, custSnap) {
                                          final custName = custSnap.data?.name ?? 'Customer';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceSubtle,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Text(
                                              custName,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      // Field Notes count
                                      StreamBuilder<List<FieldNote>>(
                                        stream: fieldNotesDao.watchNotesBySite(site.id),
                                        builder: (context, noteSnap) {
                                          final count = noteSnap.data?.length ?? 0;
                                          return Row(
                                            children: [
                                              const Icon(Icons.assignment_outlined,
                                                  size: 13, color: AppColors.textMuted),
                                              const SizedBox(width: 3),
                                              Text(
                                                '$count notes',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                              size: 20,
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
        onPressed: () => context.push(widget.customerId != null
            ? '/sites/new?customerId=${widget.customerId}'
            : '/sites/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
