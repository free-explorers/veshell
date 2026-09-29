import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/capture/provider/recording_workspaces.dart';
import 'package:shell/capture/provider/screen_cast_indicator.dart';

/// The persistent trusted indicator (capture specification section 8.3):
/// one card per **orphan** cast, naming the shared target with a Stop action.
///
/// A cast the compositor resolved to a window placed in a workspace is already
/// shown by that workspace's dot and its tile button, so it is not repeated
/// here. Only casts no workspace or tile can display (an unresolved consumer, a
/// dialog, an unplaced window) keep a card, so a recording is never invisible
/// and never duplicated. It survives workspaces because it mounts in the shell
/// rather than the content tree.
class ScreenCastIndicatorBar extends HookConsumerWidget {
  const ScreenCastIndicatorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streams = ref.watch(screenCastIndicatorProvider);
    // A cast resolved to a window is shown by its workspace and tile; only the
    // orphans no window can display keep this persistent bar.
    final orphans = ref.watch(orphanScreenCastsProvider);
    final orphanStreams = streams.values
        .where((stream) => orphans.contains(stream.sessionHandle))
        .toList();
    if (orphanStreams.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final stream in orphanStreams)
          Card(
            color: theme.colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_share),
                  const SizedBox(width: 8),
                  // One stream shortcut naming the shared target.
                  Text(stream.sourceLabel.isEmpty
                      ? "Screen sharing active"
                      : "Sharing ${stream.sourceLabel}"),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(screenCastIndicatorProvider.notifier).stop(
                              stream.sessionHandle,
                            ),
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
