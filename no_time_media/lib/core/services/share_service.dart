import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:no_time_media/core/models/post_draft.dart';

class ShareService {
  static Future<void> sharePost(PostDraft draft) async {
    final caption = draft.displayCaption;
    final hashtagString = draft.hashtags
        .map((tag) => tag.startsWith('#') ? tag : '#$tag')
        .join(' ');
    final fullCaption = '$caption\n\n$hashtagString'.trim();

    await Clipboard.setData(ClipboardData(text: fullCaption));

    final entity = await AssetEntity.fromId(draft.assetId);
    final file = await entity?.originFile ?? await entity?.file;
    if (file == null) {
      throw Exception('Could not load the original photo for sharing');
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: fullCaption,
    );
  }
}
