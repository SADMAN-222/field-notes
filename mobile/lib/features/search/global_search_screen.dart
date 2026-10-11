import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/injection.dart' as di;
import '../../core/database/database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../authentication/auth_cubit.dart';
import '../customers/customer_repository.dart';
import '../sites/site_repository.dart';
import '../field_notes/field_note_repository.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.watch<AuthCubit>();
    final userId = authCubit.currentUserId ?? '';
    final custRepo = di.sl<CustomerRepository>();
    final siteRepo = di.sl<SiteRepository>();
    final noteRepo = di.sl<FieldNoteRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search customers, sites, notes...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            setState(() => _query = val.trim());
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Customers'),
            Tab(text: 'Sites'),
            Tab(text: 'Notes'),
          ],
        ),
      ),
      body: _query.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'Search anything in your workspace',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllTab(userId, custRepo, siteRepo, noteRepo),
                _buildCustomersTab(userId, custRepo),
                _buildSitesTab(userId, siteRepo),
                _buildNotesTab(userId, noteRepo),
              ],
            ),
    );
  }

  Widget _buildAllTab(
    String userId,
    CustomerRepository custRepo,
    SiteRepository siteRepo,
    FieldNoteRepository noteRepo,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customers match
          StreamBuilder<List<Customer>>(
            stream: custRepo.searchCustomers(userId, _query),
            builder: (context, snap) {
              final customers = snap.data ?? [];
              if (customers.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CUSTOMERS (${customers.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...customers.take(3).map((c) => _buildCustomerCard(c)),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // Sites match
          StreamBuilder<List<Site>>(
            stream: siteRepo.searchSites(userId, _query),
            builder: (context, snap) {
              final sites = snap.data ?? [];
              if (sites.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SITES (${sites.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...sites.take(3).map((s) => _buildSiteCard(s)),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // Notes match
          StreamBuilder<List<FieldNote>>(
            stream: noteRepo.watchAllNotes(userId, query: _query),
            builder: (context, snap) {
              final notes = snap.data ?? [];
              if (notes.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FIELD NOTES (${notes.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...notes.take(5).map((n) => _buildNoteCard(n)),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTab(String userId, CustomerRepository repo) {
    return StreamBuilder<List<Customer>>(
      stream: repo.searchCustomers(userId, _query),
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (list.isEmpty) return const Center(child: Text('No customers found.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _buildCustomerCard(list[i]),
        );
      },
    );
  }

  Widget _buildSitesTab(String userId, SiteRepository repo) {
    return StreamBuilder<List<Site>>(
      stream: repo.searchSites(userId, _query),
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (list.isEmpty) return const Center(child: Text('No sites found.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _buildSiteCard(list[i]),
        );
      },
    );
  }

  Widget _buildNotesTab(String userId, FieldNoteRepository repo) {
    return StreamBuilder<List<FieldNote>>(
      stream: repo.watchAllNotes(userId, query: _query),
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (list.isEmpty) return const Center(child: Text('No field notes found.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _buildNoteCard(list[i]),
        );
      },
    );
  }

  Widget _buildCustomerCard(Customer c) {
    return AppCard(
      onTap: () => context.push('/customers/${c.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.business_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (c.contactInformation != null)
                  Text(c.contactInformation!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildSiteCard(Site s) {
    return AppCard(
      onTap: () => context.push('/sites/${s.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.location_city_outlined, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.siteName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (s.address != null)
                  Text(s.address!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildNoteCard(FieldNote n) {
    return AppCard(
      onTap: () => context.push('/notes/${n.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (n.description != null)
                  Text(n.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          StatusBadge(status: n.status),
        ],
      ),
    );
  }
}
