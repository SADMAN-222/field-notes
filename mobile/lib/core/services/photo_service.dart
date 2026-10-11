import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class PhotoService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  Future<String?> capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo == null) return null;
      return await _savePhotoLocally(photo);
    } catch (_) {
      return null;
    }
  }

  Future<String?> pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo == null) return null;
      return await _savePhotoLocally(photo);
    } catch (_) {
      return null;
    }
  }

  Future<String> _savePhotoLocally(XFile pickedFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final ext = p.extension(pickedFile.path).isNotEmpty ? p.extension(pickedFile.path) : '.jpg';
    final fileName = '${_uuid.v4()}$ext';
    final targetPath = p.join(photosDir.path, fileName);

    final savedFile = await File(pickedFile.path).copy(targetPath);
    return savedFile.path;
  }

  Future<bool> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  bool fileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }
}

