import 'package:hive_flutter/hive_flutter.dart';

class PrefsService {
  static Box<dynamic> get _box => Hive.box('prefs');

  static const _keyPhotoCount = 'defaultPhotoCount';

  static int get photoCount {
    final value = _box.get(_keyPhotoCount) as int?;
    return (value ?? 20).clamp(10, 50).toInt();
  }

  static Future<void> setPhotoCount(int count) async {
    await _box.put(_keyPhotoCount, count.clamp(10, 50).toInt());
  }
}
