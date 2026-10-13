import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/config/injection.dart' as di;
import '../../core/database/database.dart';
import '../../core/theme/app_colors.dart';
import '../authentication/auth_cubit.dart';
import 'customer_repository.dart';

class CustomerFormScreen extends StatefulWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _loadError;
  Customer? _existingCustomer;

  bool get isEditing => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadCustomer();
    }
  }

  Future<void> _loadCustomer() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final repo = di.sl<CustomerRepository>();
      final customer = await repo.getCustomerById(widget.customerId!);
      if (!mounted) return;
      if (customer != null) {
        _existingCustomer = customer;
        _nameController.text = customer.name;
        _contactController.text = customer.contactInformation ?? '';
      } else {
        _loadError = 'Customer was not found.';
      }
    } catch (error) {
      _loadError = 'Could not load customer: $error';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final authCubit = context.read<AuthCubit>();
    final userId = authCubit.currentUserId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No active user session.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = di.sl<CustomerRepository>();

    try {
      if (isEditing && _existingCustomer != null) {
        final updated = _existingCustomer!.copyWith(
          name: _nameController.text.trim(),
          contactInformation: Value(_contactController.text.trim()),
          updatedAt: DateTime.now().toUtc(),
          version: _existingCustomer!.version + 1,
        );
        await repo.updateCustomer(updated);
      } else {
        final newCustomer = Customer(
          id: const Uuid().v4(),
          userId: userId,
          name: _nameController.text.trim(),
          contactInformation: _contactController.text.trim().isEmpty
              ? null
              : _contactController.text.trim(),
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          version: 0,
        );
        await repo.addCustomer(newCustomer);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Customer updated' : 'Customer created'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save customer: $e'),
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
                      onPressed: _loadCustomer,
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
                              'Customer Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Company / Customer Name *',
                                hintText: 'e.g. Apex Industrial Solutions',
                                prefixIcon: Icon(
                                  Icons.business_outlined,
                                  size: 20,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter customer name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _contactController,
                              maxLines: 3,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Contact Information',
                                hintText:
                                    'Email, phone, primary point of contact...',
                                prefixIcon: Icon(
                                  Icons.contact_mail_outlined,
                                  size: 20,
                                ),
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
      appBar: AppBar(title: Text(isEditing ? 'Edit Customer' : 'New Customer')),
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
                  onPressed: _isSaving ? null : _saveCustomer,
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
                      : Text(
                          isEditing ? 'Save Changes' : 'Create Customer',
                        ),
                ),
              ),
            ),
    );
  }
}
