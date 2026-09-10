import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/models/subscription_exception.dart';
import 'package:no_time_media/core/providers/photo_scan_provider.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/providers/generation_provider.dart';

class PhotoScanScreen extends ConsumerWidget {
  const PhotoScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(photoScanProvider);
    final generation = ref.watch(generationProvider);
    final generating = generation.isLoading;

    ref.listen<AsyncValue<List<PostDraft>>>(generationProvider, (prev, next) {
      next.whenOrNull(
        data: (drafts) {
          if (drafts.isNotEmpty && context.mounted) {
            context.push('/editor', extra: drafts);
          }
        },
        error: (e, _) {
          if (!context.mounted) return;
          if (e is SubscriptionException) {
            switch (e.type) {
              case SubscriptionErrorType.requiresUpgrade:
                context.push('/paywall');
              case SubscriptionErrorType.dailyLimitReached:
                _showDailyLimitSheet(context, e.resetsAt);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Generation failed: $e')),
            );
          }
        },
      );
    });
    
    return Scaffold(
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
        onPressed: generating
            ? null
            : () async {
                final photos = ref.read(photoScanProvider).maybeWhen(
                      data: (data) => data,
                      orElse: () => <ScoredPhoto>[],
                    );
                if (photos.isEmpty) return;
                await ref
                    .read(generationProvider.notifier)
                    .generatePosts(photos);
              },
        child: generating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome),
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

void _showDailyLimitSheet(BuildContext context, DateTime? resetsAt) {
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_bottom, size: 48),
          const SizedBox(height: 12),
          const Text(
            "You've used all 20 drafts for today.",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          if (resetsAt != null)
            const Text(
              'Limit resets at midnight UTC.',
              style: TextStyle(color: Colors.grey),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}
