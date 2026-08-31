import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/models/social_platform.dart';
import 'package:no_time_media/core/providers/generation_provider.dart';
import 'package:no_time_media/core/providers/photo_scan_provider.dart';
import 'package:no_time_media/core/services/draft_service.dart';
import 'package:no_time_media/core/services/share_service.dart';

class PostEditorScreen extends ConsumerStatefulWidget {
  const PostEditorScreen({super.key, required this.drafts});

  final List<PostDraft> drafts;

  @override
  ConsumerState<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends ConsumerState<PostEditorScreen> {
  static const _captionLimit = 300;

  late List<PostDraft> _drafts;
  late final PageController _pageController;
  late final TextEditingController _captionController;
  int _page = 0;
  bool _rationaleExpanded = false;
  bool _busy = false;

  PostDraft get _current => _drafts[_page];

  @override
  void initState() {
    super.initState();
    _drafts = List<PostDraft>.from(widget.drafts);
    _pageController = PageController();
    _captionController = TextEditingController(text: _current.effectiveCaption);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _page = index;
      _rationaleExpanded = false;
      _captionController.text = _current.effectiveCaption;
    });
  }

  void _onCaptionChanged(String value) {
    setState(() {
      if (value == _current.caption) {
        _current.userEditedCaption = null;
      } else {
        _current.userEditedCaption = value;
      }
    });
  }

  Future<void> _saveDraft() async {
    try {
      await DraftService.save(_current);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _share() async {
    try {
      setState(() => _busy = true);
      await ShareService.sharePost(_current);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Caption copied to clipboard — paste it in Instagram',
          ),
        ),
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Did you share it?'),
          content: const Text(
            'Mark this draft as shared so you can find it later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not yet'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        _current.isShared = true;
        await DraftService.save(_current);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate() async {
    final photos = ref.read(photoScanProvider).maybeWhen(
          data: (data) => data,
          orElse: () => <ScoredPhoto>[],
        );
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No scanned photos to regenerate from')),
      );
      return;
    }

    try {
      setState(() => _busy = true);
      await ref.read(generationProvider.notifier).generatePosts(photos);
      if (!mounted) return;
      final result = ref.read(generationProvider);
      result.whenData((drafts) {
        if (drafts.isEmpty) return;
        setState(() {
          _drafts = List<PostDraft>.from(drafts);
          _page = 0;
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
        _captionController.text = _current.effectiveCaption;
      });
      result.whenOrNull(
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Regeneration failed: $e')),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openHashtagEditor() async {
    final tags = List<String>.from(_current.hashtags);
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit hashtags',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final tag in tags)
                        InputChip(
                          label: Text(tag.startsWith('#') ? tag : '#$tag'),
                          onDeleted: () {
                            setSheetState(() => tags.remove(tag));
                          },
                        ),
                    ],
                  ),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Add hashtag',
                    ),
                    onSubmitted: (value) {
                      final tag = value.trim().replaceAll('#', '');
                      if (tag.isEmpty || tags.contains(tag)) return;
                      setSheetState(() => tags.add(tag));
                      controller.clear();
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    controller.dispose();
    setState(() {
      _current.hashtags = tags;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_drafts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Time Media')),
        body: const Center(child: Text('No drafts to edit')),
      );
    }

    final pageLabel = '${_page + 1}/${_drafts.length}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('No Time Media'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(pageLabel),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _drafts.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    final platform =
                        SocialPlatform.fromString(draft.platform).displayName;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: draft.thumbnail.isEmpty
                                ? const ColoredBox(color: Colors.grey)
                                : Image.memory(
                                    draft.thumbnail,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            avatar: const Icon(Icons.camera_alt, size: 16),
                            label: Text(platform),
                          ),
                        ),
                        if (draft.engagementRationale.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _rationaleExpanded = !_rationaleExpanded;
                                });
                              },
                              child: Text(
                                draft.engagementRationale,
                                maxLines: _rationaleExpanded ? null : 1,
                                overflow: _rationaleExpanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        if (index == _page) ...[
                          TextField(
                            controller: _captionController,
                            minLines: 3,
                            maxLines: 6,
                            onChanged: _onCaptionChanged,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(_captionLimit),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Caption',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          Row(
                            children: [
                              const Spacer(),
                              Text(
                                '${_captionController.text.length}/$_captionLimit',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              if (_current.userEditedCaption != null)
                                IconButton(
                                  tooltip: 'Undo',
                                  onPressed: () {
                                    _current.userEditedCaption = null;
                                    _captionController.text = _current.caption;
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.undo),
                                ),
                            ],
                          ),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final tag in _current.hashtags)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InputChip(
                                      label: Text(
                                        tag.startsWith('#') ? tag : '#$tag',
                                      ),
                                      onDeleted: () {
                                        setState(() {
                                          _current.hashtags = _current.hashtags
                                              .where((h) => h != tag)
                                              .toList();
                                        });
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _openHashtagEditor,
                              child: const Text('Edit Hashtags'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _regenerate,
                          child: const Text('Regenerate'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _saveDraft,
                          child: const Text('Save Draft'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _share,
                          child: const Text('Share ↗'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
