import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/services/prefs_service.dart';

final photoCountProvider = NotifierProvider<PhotoCountNotifier, int>(
  PhotoCountNotifier.new,
);

class PhotoCountNotifier extends Notifier<int> {
  @override
  int build() => PrefsService.photoCount;

  Future<void> setCount(int count) async {
    await PrefsService.setPhotoCount(count);
    state = PrefsService.photoCount;
  }
}
