import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/config/injection.dart' as di;
import '../../core/database/database.dart';
import '../../core/services/location_service.dart';
import '../../core/services/photo_service.dart';
import '../../core/storage/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../authentication/auth_cubit.dart';
import '../sites/site_repository.dart';
import 'field_note_repository.dart';

class NoteFormScreen extends StatefulWidget {
  final String? siteId;
  final String? noteId;

  const NoteFormScreen({super.key, this.siteId, this.noteId});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedSiteId;
  String _status = 'DRAFT';
  double? _latitude;
  double? _longitude;
  String? _photoPath;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isCapturingLocation = false;
  FieldNote? _existingNote;
  List<Site> _sites = [];

  final List<String> _statusOptions = ['DRAFT', 'SUBMITTED', 'COMPLETED', 'CANCELLED'];

  bool get isEditing => widget.noteId != null;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.siteId;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final authCubit = context.read<AuthCubit>();
    final userId = authCubit.currentUserId ?? '';
    final siteRepo = di.sl<SiteRepository>();
    final noteRepo = di.sl<FieldNoteRepository>();
    final prefs = di.sl<PreferencesService>();

    final sites = await siteRepo.getAllSites(userId);
    FieldNote? note;
    if (isEditing) {
      note = await noteRepo.getNoteById(widget.noteId!);
    }

    if (mounted) {
      setState(() {
        _sites = sites;
        if (note != null) {
          _existingNote = note;
          _titleController.text = note.title;
          _descController.text = note.description ?? '';
          _selectedSiteId = note.siteId;
          _status = note.status;
          _latitude = note.lat;
          _longitude = note.lng;
          _photoPath = note.photoPath;
        } else {
          _status = prefs.defaultNoteStatus;
          if (_selectedSiteId == null && sites.isNotEmpty) {
            _selectedSiteId = sites.first.id;
          }
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _isCapturingLocation = true);
    final locationService = di.sl<LocationService>();
    final loc = await locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _isCapturingLocation = false;
        if (loc != null) {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS captured: ${loc.formattedCoordinates}'),
              backgroundColor: AppColors.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not determine GPS coordinates. Check permissions.'),
              backgroundColor: AppColors.syncWarning,
            ),
          );
        }
      });
    }
  }

  Future<void> _pickPhoto(bool fromCamera) async {
    final photoService = di.sl<PhotoService>();
    final path = fromCamera
        ? await photoService.capturePhoto()
        : await photoService.pickFromGallery();

    if (mounted && path != null) {
      setState(() {
        _photoPath = path;
      });
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site for this note.')),
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
    final noteRepo = di.sl<FieldNoteRepository>();

    try {
      if (isEditing && _existingNote != null) {
        final updated = _existingNote!.copyWith(
          title: _titleController.text.trim(),
          description: Value(_descController.text.trim().isEmpty ? null : _descController.text.trim()),
          status: _status,
          siteId: _selectedSiteId!,
          lat: Value(_latitude),
          lng: Value(_longitude),
          photoPath: Value(_photoPath),
          updatedAt: DateTime.now().toUtc(),
          version: _existingNote!.version + 1,
        );
        await noteRepo.updateNote(updated);
      } else {
        final newNote = FieldNote(
          id: const Uuid().v4(),
          userId: userId,
          siteId: _selectedSiteId!,
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          status: _status,
          lat: _latitude,
          lng: _longitude,
          photoPath: _photoPath,
          recordedAt: DateTime.now().toUtc(),
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          version: 0,
        );
        await noteRepo.addNote(newNote);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Field note updated' : 'Field note saved'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save field note: $e'),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Field Note' : 'New Field Note'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form fields card
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
                            'General Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Site selector
                          if (_sites.isEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.syncWarning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.syncWarning.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: AppColors.syncWarning, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: const Text(
                                      'No sites available. Please create a site first.',
                                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => context.push('/sites/new'),
                                    child: const Text('Add Site'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSiteId,
                              decoration: const InputDecoration(
                                labelText: 'Site Location *',
                                prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                              ),
                              items: _sites.map((s) {
                                return DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.siteName, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedSiteId = val);
                              },
                              validator: (val) => val == null ? 'Please select a site' : null,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Title
                          TextFormField(
                            controller: _titleController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Note Title *',
                              hintText: 'e.g. Foundation Crack Inspection',
                              prefixIcon: Icon(Icons.title, size: 20),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter note title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Status Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: 'Inspection Status *',
                              prefixIcon: Icon(Icons.flag_outlined, size: 20),
                            ),
                            items: _statusOptions.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _status = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: _descController,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Observations & Notes',
                              hintText: 'Enter detailed findings, measurements, or actions taken...',
                              prefixIcon: Icon(Icons.notes_outlined, size: 20),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Media & Attachments Card
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
                            'Photo Attachment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_photoPath != null && File(_photoPath!).existsSync()) ...[
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(_photoPath!),
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                      onPressed: () {
                                        setState(() => _photoPath = null);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickPhoto(true),
                                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                  label: const Text('Camera'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickPhoto(false),
                                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                                  label: const Text('Gallery'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // GPS Coordinates Card
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
                            'Geotag Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_latitude != null && _longitude != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.my_location, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        const Text(
                                          'GPS Captured',
                                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                                    onPressed: () {
                                      setState(() {
                                        _latitude = null;
                                        _longitude = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          OutlinedButton.icon(
                            onPressed: _isCapturingLocation ? null : _captureLocation,
                            icon: _isCapturingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.gps_fixed, size: 18),
                            label: Text(_latitude != null ? 'Recapture GPS Location' : 'Capture Current Location'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveNote,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(isEditing ? 'Save Changes' : 'Record Field Note'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
