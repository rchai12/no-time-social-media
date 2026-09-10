import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:no_time_media/core/services/prefs_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ntm_prefs_');
    Hive.init(tempDir.path);
    await Hive.openBox(PrefsService.boxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('default photo count is 20', () {
    expect(PrefsService.getDefaultPhotoCount(), 20);
  });

  test('persists a value in the 10–50 range', () async {
    await PrefsService.setDefaultPhotoCount(35);
    expect(PrefsService.getDefaultPhotoCount(), 35);
  });

  test('clamps values outside 10–50', () async {
    await PrefsService.setDefaultPhotoCount(3);
    expect(PrefsService.getDefaultPhotoCount(), 10);

    await PrefsService.setDefaultPhotoCount(99);
    expect(PrefsService.getDefaultPhotoCount(), 50);
  });
}
