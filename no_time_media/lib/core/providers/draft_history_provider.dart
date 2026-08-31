import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/services/draft_service.dart';

final draftHistoryProvider = StreamProvider<List<PostDraft>>((ref) {
  return ref.watch(draftServiceProvider).watch();
});
