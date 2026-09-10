import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/providers/photo_scan_provider.dart';
import 'package:no_time_media/core/services/prefs_service.dart';

final photoCountProvider =
    NotifierProvider<PhotoCountNotifier, int>(PhotoCountNotifier.new);

class PhotoCountNotifier extends Notifier<int> {
  @override
  int build() => PrefsService.getDefaultPhotoCount();

  Future<void> setCount(int count) async {
    final clamped = count
        .clamp(PrefsService.minPhotoCount, PrefsService.maxPhotoCount)
        .toInt();
    await PrefsService.setDefaultPhotoCount(clamped);
    state = clamped;
    ref.invalidate(photoScanProvider);
  }
}
