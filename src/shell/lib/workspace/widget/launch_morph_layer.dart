import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/launch_morphs.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/launch_morph.dart';

/// Draws the launch morphs of a workspace's tiles above its tile row.
///
/// A tile launched from the tiled launcher takes the launcher's place, and
/// the launcher slides aside to the next slot. Slots paint in order, so the
/// sliding launcher would cover a morph drawn in the tile: drawn here, linked
/// to the tile ([LaunchMorphRequest.link]), the morph stays on top and the
/// launcher moves aside under it.
class LaunchMorphLayer extends ConsumerWidget {
  const LaunchMorphLayer({required this.windowIds, super.key});

  /// The workspace's tiles.
  final IList<PersistentWindowId> windowIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final morphs = ref.watch(launchMorphsProvider);
    final active = [
      for (final windowId in windowIds)
        if (morphs[windowId] case final request?) (windowId, request),
    ];
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (windowId, request) in active)
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: request.link,
                showWhenUnlinked: false,
                child: SizedBox.fromSize(
                  size: request.launcherRect.size,
                  child: Consumer(
                    builder: (context, ref, _) => LaunchMorph(
                      key: ObjectKey(request),
                      window: ref.watch(
                        persistentWindowStateProvider(windowId),
                      ),
                      request: request,
                      onDone: () => ref
                          .read(launchMorphsProvider.notifier)
                          .finish(windowId),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
