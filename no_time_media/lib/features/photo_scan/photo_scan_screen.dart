import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shimmer/shimmer.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/models/subscription_exception.dart';
import 'package:no_time_media/core/providers/generation_provider.dart';
import 'package:no_time_media/core/providers/photo_scan_provider.dart';
import 'package:no_time_media/core/services/photo_service.dart';
import 'package:no_time_media/core/utils/score_tier.dart';

class PhotoScanScreen extends ConsumerStatefulWidget {
  const PhotoScanScreen({super.key});

  @override
  ConsumerState<PhotoScanScreen> createState() => _PhotoScanScreenState();
}

class _PhotoScanScreenState extends ConsumerState<PhotoScanScreen> {
  final Set<String> _deselected = {};

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(photoScanProvider);
    final generation = ref.watch(generationProvider);
    final generating = generation.isLoading;

    ref.listen(photoScanProvider, (prev, next) {
      next.whenData((_) {
        if (mounted) setState(() => _deselected.clear());
      });
    });

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

    return photosAsync.when(
      data: (photos) {
        if (photos.isEmpty) {
          return const Center(child: Text('No photos found'));
        }

        final selected = photos
            .where((photo) => !_deselected.contains(photo.id))
            .toList();

        return Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: photos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return _PhotoTile(
                    photo: photo,
                    tier: scoreTierForIndex(index, photos.length),
                    deselected: _deselected.contains(photo.id),
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        if (_deselected.contains(photo.id)) {
                          _deselected.remove(photo.id);
                        } else {
                          _deselected.add(photo.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: generating || selected.isEmpty
                        ? null
                        : () => ref
                            .read(generationProvider.notifier)
                            .generatePosts(selected),
                    icon: generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('Generate Posts'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const _ShimmerGrid(),
      error: (error, stackTrace) {
        if (error is PhotoPermissionDeniedException) {
          return _PermissionDeniedView(
            onRetry: () => ref.invalidate(photoScanProvider),
          );
        }
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Error loading photos: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(photoScanProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.tier,
    required this.deselected,
    required this.onLongPress,
  });

  final ScoredPhoto photo;
  final ScoreTier tier;
  final bool deselected;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
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
              Widget image;
              if (snapshot.hasData && snapshot.data != null) {
                image = Image.memory(snapshot.data!, fit: BoxFit.cover);
              } else if (snapshot.hasError) {
                image = const ColoredBox(
                  color: Colors.grey,
                  child: Icon(Icons.broken_image, color: Colors.white),
                );
              } else {
                image = const ColoredBox(color: Colors.grey);
              }

              if (!deselected) return image;
              return ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.saturation,
                ),
                child: Opacity(opacity: 0.55, child: image),
              );
            },
          ),
          if (tier != ScoreTier.none)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.star,
                size: 20,
                color: tier == ScoreTier.gold
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFC0C0C0),
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          if (deselected)
            const ColoredBox(
              color: Color(0x66000000),
              child: Icon(Icons.remove_circle, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: 12,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: const ColoredBox(color: Colors.white),
        );
      },
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            'Photo access is required',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'No Time Media needs access to your photos to score and select '
            'the best ones for your posts.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => PhotoManager.openSetting(),
            child: const Text('Open Settings'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
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
