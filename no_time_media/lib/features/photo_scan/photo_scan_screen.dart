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

  Future<void> _onGenerate(List<ScoredPhoto> photos) {
    final selected =
        photos.where((photo) => !_deselected.contains(photo.id)).toList();
    if (selected.isEmpty) return Future.value();
    return ref.read(generationProvider.notifier).generatePosts(selected);
  }

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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('Generate Posts'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: generating || !photosAsync.hasValue
                        ? null
                        : () => _onGenerate(photos),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => GridView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: 20,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(color: Colors.white),
        ),
      ),
      error: (error, _) {
        final isPermission = error is PhotoPermissionDeniedException ||
            error.toString().contains('Permission denied') ||
            error.toString().contains('denied');
        if (isPermission) {
          return const _PermissionDeniedView();
        }
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Error: $error'),
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
    required this.deselected,
    required this.onLongPress,
  });

  final ScoredPhoto photo;
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
            top: 4,
            right: 4,
            child: _scoreBadge(photo.compositeScore),
          ),
          if (deselected)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x80000000),
                child: Icon(Icons.close, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scoreBadge(double score) {
    final tier = scoreTierForScore(score);
    if (tier == ScoreTier.none) return const SizedBox.shrink();
    return Icon(
      Icons.star_rounded,
      size: 20,
      color: tier == ScoreTier.gold
          ? const Color(0xFFFFD700)
          : const Color(0xFFC0C0C0),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Photo Access Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'No Time Media needs access to your photo library to find and score your best photos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            _OpenSettingsButton(),
          ],
        ),
      ),
    );
  }
}

class _OpenSettingsButton extends StatelessWidget {
  const _OpenSettingsButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.settings),
      label: const Text('Open Settings'),
      onPressed: () => PhotoManager.openSetting(),
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
