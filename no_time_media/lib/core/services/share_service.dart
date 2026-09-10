import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:no_time_media/core/models/post_draft.dart';

class ShareService {
  static Future<void> sharePost(PostDraft draft) async {
    final hashtagString = draft.hashtags.map((h) => '#$h').join(' ');
    final fullCaption = '${draft.effectiveCaption}\n\n$hashtagString';

    await Clipboard.setData(ClipboardData(text: fullCaption));

    final entity = AssetEntity(
      id: draft.assetId,
      typeInt: 1,
      width: 0,
      height: 0,
    );
    final file = await entity.file;
    if (file == null) throw Exception('Could not access photo file');

    // share_plus 9.0.0 does not include SharePlus.instance / ShareParams.
    await Share.shareXFiles(
      [XFile(file.path)],
      text: fullCaption,
    );
  }
}
