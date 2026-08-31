import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
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
  late final TextEditingController _hashtagController;
  int _page = 0;
  bool _rationaleExpanded = false;
  bool _busy = false;

  PostDraft get _current => _drafts[_page];

  @override
  void initState() {
    super.initState();
    _drafts = List<PostDraft>.from(widget.drafts);
    _pageController = PageController();
    _captionController = TextEditingController(text: _current.displayCaption);
    _hashtagController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  void _applyCaption(String value) {
    final draft = _current;
    if (value == draft.caption) {
      draft.userEditedCaption = null;
    } else {
      draft.userEditedCaption = value;
    }
    setState(() {});
  }

  void _goToPage(int index) {
    final next = index.clamp(0, _drafts.length - 1);
    _page = next;
    _captionController.text = _current.displayCaption;
    _hashtagController.clear();
    _rationaleExpanded = false;
    setState(() {});
  }

  void _addHashtag(String raw) {
    final tag = raw.trim().replaceAll('#', '');
    if (tag.isEmpty) return;
    if (_current.hashtags.contains(tag)) {
      _hashtagController.clear();
      return;
    }
    setState(() {
      _current.hashtags = [..._current.hashtags, tag];
    });
    _hashtagController.clear();
  }

  void _removeHashtag(String tag) {
    setState(() {
      _current.hashtags = _current.hashtags.where((h) => h != tag).toList();
    });
  }

  Future<void> _saveDraft() async {
    try {
      await ref.read(draftServiceProvider).save(_current);
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
        await ref.read(draftServiceProvider).save(_current);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as shared')),
        );
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
      final drafts =
          await ref.read(generationProvider.notifier).generatePosts(photos);
      if (!mounted) return;
      if (drafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No posts were generated')),
        );
        return;
      }
      setState(() {
        _drafts = drafts;
        _page = 0;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _captionController.text = _current.displayCaption;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regeneration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_drafts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Time Media')),
        body: const Center(child: Text('No drafts to edit')),
      );
    }

    final captionLength = _captionController.text.length;
    final overLimit = captionLength > _captionLimit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('No Time Media'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_drafts.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _drafts.length,
                      (i) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _drafts.length,
                  onPageChanged: _goToPage,
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
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
                            label: Text(draft.socialPlatform.displayName),
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
                            onChanged: _applyCaption,
                            decoration: const InputDecoration(
                              labelText: 'Caption',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '$captionLength/$_captionLimit',
                              style: TextStyle(
                                color: overLimit ? Colors.red : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (_current.userEditedCaption != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  _current.userEditedCaption = null;
                                  _captionController.text = _current.caption;
                                  setState(() {});
                                },
                                child: const Text('Undo'),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final tag in _current.hashtags)
                                InputChip(
                                  label: Text(
                                    tag.startsWith('#') ? tag : '#$tag',
                                  ),
                                  onDeleted: () => _removeHashtag(tag),
                                ),
                            ],
                          ),
                          TextField(
                            controller: _hashtagController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: _addHashtag,
                            decoration: const InputDecoration(
                              labelText: 'Add hashtag',
                              hintText: 'travel',
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
                          child: const Text('Share'),
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
