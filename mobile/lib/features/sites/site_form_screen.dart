import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/config/injection.dart' as di;
import '../../core/database/database.dart';
import '../../core/theme/app_colors.dart';
import '../authentication/auth_cubit.dart';
import '../customers/customer_repository.dart';
import 'site_repository.dart';

class SiteFormScreen extends StatefulWidget {
  final String? customerId;
  final String? siteId;

  const SiteFormScreen({super.key, this.customerId, this.siteId});

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedCustomerId;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _loadError;
  Site? _existingSite;
  List<Customer> _customers = [];

  bool get isEditing => widget.siteId != null;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.customerId;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final authCubit = context.read<AuthCubit>();
      final userId = authCubit.currentUserId ?? '';
      final custRepo = di.sl<CustomerRepository>();
      final siteRepo = di.sl<SiteRepository>();
      final customers = await custRepo.getAllCustomers(userId);
      Site? site;
      if (isEditing) {
        site = await siteRepo.getSiteById(widget.siteId!);
        if (site == null) {
          throw StateError('Site was not found.');
        }
      }

      if (!mounted) return;
      setState(() {
        _customers = customers;
        if (site != null) {
          _existingSite = site;
          _nameController.text = site.siteName;
          _addressController.text = site.address ?? '';
          _selectedCustomerId = site.customerId;
        } else if (_selectedCustomerId == null && customers.isNotEmpty) {
          _selectedCustomerId = customers.first.id;
        }
      });
    } catch (error) {
      _loadError = 'Could not load site form: $error';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveSite() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer for this site.'),
        ),
      );
      return;
    }

    final authCubit = context.read<AuthCubit>();
    final userId = authCubit.currentUserId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No active user session.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final siteRepo = di.sl<SiteRepository>();

    try {
      if (isEditing && _existingSite != null) {
        final updated = _existingSite!.copyWith(
          siteName: _nameController.text.trim(),
          address: Value(_addressController.text.trim()),
          customerId: _selectedCustomerId!,
          updatedAt: DateTime.now().toUtc(),
          version: _existingSite!.version + 1,
        );
        await siteRepo.updateSite(updated);
      } else {
        final newSite = Site(
          id: const Uuid().v4(),
          userId: userId,
          customerId: _selectedCustomerId!,
          siteName: _nameController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          version: 0,
        );
        await siteRepo.addSite(newSite);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Site updated' : 'Site created'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save site: $e'),
            backgroundColor: AppColors.syncError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loadInitialData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 92),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Site Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_customers.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.syncWarning.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.syncWarning.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.syncWarning,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'No customers found. Please create a customer first.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          context.push('/customers/new'),
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ] else ...[
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCustomerId,
                                decoration: const InputDecoration(
                                  labelText: 'Customer *',
                                  prefixIcon: Icon(
                                    Icons.business_outlined,
                                    size: 20,
                                  ),
                                ),
                                items: _customers.map((c) {
                                  return DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      c.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedCustomerId = val);
                                },
                                validator: (val) => val == null
                                    ? 'Please select a customer'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                            ],

                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Site Name *',
                                hintText: 'e.g. North Terminal Substation',
                                prefixIcon: Icon(
                                  Icons.location_on_outlined,
                                  size: 20,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter site name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _addressController,
                              maxLines: 3,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Physical Address',
                                hintText:
                                    'Street address, building, gate, or GPS reference...',
                                prefixIcon: Icon(Icons.map_outlined, size: 20),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEditing ? 'Edit Site' : 'New Site')),
      body: bodyContent,
      bottomNavigationBar: _isLoading || _loadError != null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveSite,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(isEditing ? 'Save Changes' : 'Create Site'),
                ),
              ),
            ),
    );
  }
}
