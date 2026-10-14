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
import 'customer_repository.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
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
    final repo = di.sl<CustomerRepository>();
    final sitesDao = di.sl<SitesDao>();
    final syncEngine = di.sl<SyncEngine>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customers'),
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
          // Search & Filter header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),
          const Divider(height: 1),

          // Customer list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => syncEngine.sync(),
              child: StreamBuilder<List<Customer>>(
                stream: _searchQuery.isEmpty
                    ? repo.watchCustomers(userId)
                    : repo.searchCustomers(userId, _searchQuery),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load customers: ${snapshot.error}',
                      ),
                    );
                  }

                  final customers = snapshot.data ?? [];

                  if (customers.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.people_outline,
                      title: _searchQuery.isEmpty
                          ? 'No Customers Found'
                          : 'No Results Found',
                      subtitle: _searchQuery.isEmpty
                          ? 'Add your first customer to start tracking sites and inspection notes.'
                          : 'Try modifying your search query.',
                      actionLabel: _searchQuery.isEmpty ? 'Add Customer' : null,
                      onAction: _searchQuery.isEmpty
                          ? () => context.push('/customers/new')
                          : null,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return AppCard(
                        onTap: () => context.push('/customers/${customer.id}'),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.business_outlined,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (customer.contactInformation != null &&
                                      customer.contactInformation!
                                          .trim()
                                          .isNotEmpty) ...[
                                    Text(
                                      customer.contactInformation!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  FutureBuilder<List<Site>>(
                                    future: sitesDao.getSitesByCustomer(
                                      customer.id,
                                      userId,
                                    ),
                                    builder: (context, siteSnap) {
                                      final count = siteSnap.data?.length ?? 0;
                                      return Row(
                                        children: [
                                          const Icon(
                                            Icons.location_city_outlined,
                                            size: 14,
                                            color: AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$count ${count == 1 ? "site" : "sites"}',
                                            style: const TextStyle(
                                              fontSize: 12,
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
        onPressed: () => context.push('/customers/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
