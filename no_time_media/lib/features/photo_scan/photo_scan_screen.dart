import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:no_time_media/core/providers/photo_scan_provider.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/providers/generation_provider.dart';

class PhotoScanScreen extends ConsumerWidget {
  const PhotoScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(photoScanProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh the photo list
              ref.invalidate(photoScanProvider);
            },
          ),
        ],
      ),
      body: photosAsync.when(
        data: (photos) {
          if (photos.isEmpty) {
            return const Center(
              child: Text('No photos found'),
            );
          }
          
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final photo = photos[index];
              return _buildPhotoThumbnail(context, photo);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Error loading photos: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(photoScanProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final photos = ref.read(photoScanProvider).maybeWhen(
            data: (data) => data,
            orElse: () => <ScoredPhoto>[],
          );
          if (photos.isEmpty) return;
          try {
            await ref.read(generationProvider.notifier).generatePosts(photos);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Generation failed: $e')),
              );
            }
          }
        },
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }
  
  Widget _buildPhotoThumbnail(BuildContext context, ScoredPhoto photo) {
    return GestureDetector(
      onTap: () {
        // Navigate to post editor with this photo
        // This would be implemented in a later stage
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: AssetEntity(
              id: photo.id,
              typeInt: 1,
              width: photo.width,
              height: photo.height,
            ).thumbnailDataWithSize(const ThumbnailSize(200, 200)),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              }
              if (snapshot.hasError) {
                return const ColoredBox(
                  color: Colors.grey,
                  child: Icon(Icons.broken_image, color: Colors.white),
                );
              }
              return const ColoredBox(color: Colors.grey);
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              padding: const EdgeInsets.all(4),
              child: Text(
                photo.compositeScore.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}