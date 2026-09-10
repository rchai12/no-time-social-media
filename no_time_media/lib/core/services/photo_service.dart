import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:no_time_media/core/models/photo_entity.dart';

class PhotoPermissionDeniedException implements Exception {
  const PhotoPermissionDeniedException();

  @override
  String toString() => 'Permission denied';
}

class PhotoFetchResult {
  const PhotoFetchResult({required this.photos, this.isLimited = false});

  final List<PhotoEntity> photos;
  final bool isLimited;
}

class PhotoService {
  /// Fetches the last N photos from the device gallery, newest first.
  static Future<PhotoFetchResult> fetchLastPhotos(int count) async {
    try {
      debugPrint('Checking permissions...');

      final status = await PhotoManager.requestPermissionExtend();
      debugPrint('Permission status: $status');

      // isAuth is true for both authorized AND limited
      if (!status.isAuth) {
        throw const PhotoPermissionDeniedException();
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(),
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      if (albums.isEmpty) {
        return PhotoFetchResult(photos: const [], isLimited: status.isLimited);
      }

      final List<AssetEntity> assets =
          await albums.first.getAssetListRange(start: 0, end: count);

      final List<PhotoEntity> photos = [];

      for (final asset in assets) {
        try {
          final file = await asset.file;
          if (file == null) continue;

          photos.add(PhotoEntity(
            id: asset.id,
            path: file.path,
            width: asset.width,
            height: asset.height,
            dateTaken: asset.createDateSecond != null
                ? asset.createDateTime
                : DateTime.now(),
            isFavorited: asset.isFavorite,
            score: null,
          ));
        } catch (e) {
          debugPrint('Error getting asset ${asset.id}: $e');
          continue;
        }
      }

      return PhotoFetchResult(photos: photos, isLimited: status.isLimited);
    } catch (e) {
      debugPrint('Error in fetchLastPhotos: $e');
      rethrow;
    }
  }
}
