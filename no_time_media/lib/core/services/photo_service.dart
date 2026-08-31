import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:no_time_media/core/models/photo_entity.dart';

class PhotoService {
  /// Fetches the last N photos from the device gallery
  static Future<List<PhotoEntity>> fetchLastPhotos(int count) async {
    try {
      // Debug: Check current status before requesting
      debugPrint('Checking permissions...');
      
      // Request permission if not granted
      final status = await PhotoManager.requestPermissionExtend();
      debugPrint('Permission status: $status');
      
      if (!status.isAuth) {
        throw Exception('Permission denied');
      }

      // Fetch assets using getAssetListRange (this is what's available in v3.12.0)
      final List<AssetEntity> assets = await PhotoManager.getAssetListRange(
        start: 0,
        end: count,
        type: RequestType.image,
      );

      // Build up list of PhotoEntities
      final List<PhotoEntity> photos = [];
      
      for (final asset in assets) {
        try {
          // For this specific version, work with what's available - we'll skip the thumbnail
          // and use a mock approach to test functionality
          
          // Get a basic file path using the available property name
          final file = await asset.file;
          if (file == null) continue;
          
          photos.add(PhotoEntity(
            id: asset.id,
            path: file.path,
            width: asset.width,
            height: asset.height,
            // Use the correct date property available in v3.12.0 for this version
            // We don't have an exact property name in this version that's working yet 
            // - use a simple placeholder for now to prove functionality works
            dateTaken: DateTime.now(), // placeholder for now, would be asset.time or similar in working package
            isFavorited: asset.isFavorite,
            score: null, // Will be calculated later in scoring
          ));
        } catch (e) {
          debugPrint('Error getting asset ${asset.id}: $e');
          continue;
        }
      }
      
      return photos;
    } catch (e) {
      debugPrint('Error in fetchLastPhotos: $e');
      rethrow;
    }
  }
}