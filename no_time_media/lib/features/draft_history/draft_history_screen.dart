import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:no_time_media/core/providers/draft_history_provider.dart';
import 'package:no_time_media/core/services/draft_service.dart';

class DraftHistoryScreen extends ConsumerWidget {
  const DraftHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(draftHistoryProvider);

    return Scaffold(
      body: draftsAsync.when(
        data: (drafts) {
          if (drafts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.drafts_outlined, size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No saved drafts yet'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              return Dismissible(
                key: ValueKey(draft.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Delete draft?'),
                      content: const Text('This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) {
                  DraftService.delete(draft.id);
                },
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: draft.thumbnail.isEmpty
                        ? const SizedBox(
                            width: 56,
                            height: 56,
                            child: ColoredBox(color: Colors.grey),
                          )
                        : Image.memory(
                            draft.thumbnail,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                  ),
                  title: Text(
                    draft.effectiveCaption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${draft.platform} · ${_formatDate(draft.createdAt)}',
                  ),
                  trailing: draft.isShared
                      ? const Icon(Icons.ios_share, color: Colors.green)
                      : null,
                  onTap: () {
                    context.push('/editor', extra: [draft]);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Could not load drafts: $error'),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
