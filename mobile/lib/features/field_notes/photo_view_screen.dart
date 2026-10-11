import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PhotoViewScreen extends StatelessWidget {
  final String photoPath;

  const PhotoViewScreen({super.key, required this.photoPath});

  @override
  Widget build(BuildContext context) {
    final file = File(photoPath);
    final exists = file.existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Inspection Photo', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: !exists
            ? const Text(
                'Photo file not found on local storage.',
                style: TextStyle(color: Colors.white70),
              )
            : InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Text(
                    'Error rendering photo.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
      ),
    );
  }
}

