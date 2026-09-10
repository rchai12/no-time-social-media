import 'package:hive_flutter/hive_flutter.dart';

class PrefsService {
  static const boxName = 'prefs';
  static const photoCountKey = 'defaultPhotoCount';
  static const defaultPhotoCount = 20;
  static const minPhotoCount = 10;
  static const maxPhotoCount = 50;

  static Box<dynamic> get _box => Hive.box(boxName);

  static int getDefaultPhotoCount() {
    final value = _box.get(photoCountKey, defaultValue: defaultPhotoCount);
    if (value is int) {
      return value.clamp(minPhotoCount, maxPhotoCount).toInt();
    }
    return defaultPhotoCount;
  }

  static Future<void> setDefaultPhotoCount(int count) async {
    await _box.put(
      photoCountKey,
      count.clamp(minPhotoCount, maxPhotoCount).toInt(),
    );
  }
}
