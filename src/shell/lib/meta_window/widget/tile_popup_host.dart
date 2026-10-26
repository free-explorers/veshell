import 'dart:async';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_popup.serializable.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_for_id.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_popup.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

/// Renders every popup owned by a tile in one tile-level coordinate space.
///
/// Popup positions are tile-relative. This host is the only popup surface
/// stack: floating, maximized, fullscreen and game tiles all use it, so there
/// is no display-mode-specific popup placement path.
class TilePopupHost extends HookConsumerWidget {
  const TilePopupHost({required this.metaWindowIds, super.key});

  final List<MetaWindowId> metaWindowIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popupIds = <MetaPopupId>[];
    final seenParentIds = <MetaWindowId>{};
    for (final metaWindowId in metaWindowIds) {
      if (!seenParentIds.add(metaWindowId)) {
        continue;
      }
      popupIds.addAll(ref.watch(metaPopupForIdProvider(metaWindowId)));
    }

    final hostKey = useMemoized(GlobalKey.new);
    final monitorName = CurrentMonitorName.of(context);
    final monitorLocation =
        ref.watch(monitorByNameProvider(monitorName))?.location ?? Offset.zero;
    final metaWindowIdsKey = metaWindowIds.join('\u0000');
    final monitorKey =
        '$monitorName:${monitorLocation.dx},${monitorLocation.dy}';
    final tileMotionKey = metaWindowIds
        .map((metaWindowId) => _motionKeyFor(ref, metaWindowId))
        .join('|');

    // Publish the tile origin so Rust can normalize native X11 popup
    // coordinates and derive global pointer origins. Rendering does not use
    // this value: popup positions are already tile-relative.
    //
    // The tile can move by a render transform without rebuilding this host.
    // Watching the parent window's position/render origin makes the effect run
    // when that transform changes, instead of keeping the origin measured
    // during the overview animation forever.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        final renderBox =
            hostKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) {
          return;
        }
        final origin = renderBox.localToGlobal(Offset.zero) + monitorLocation;
        for (final metaWindowId in metaWindowIds) {
          try {
            unawaited(
              ref
                  .read(metaWindowStateProvider(metaWindowId).notifier)
                  .patch(
                    MetaWindowPatchMessage.updateTileOrigin(
                      id: metaWindowId,
                      value: origin,
                    ),
                  ),
            );
          } catch (_) {
            // The window can disappear between the frame and this callback.
            // The remaining windows should still receive the origin.
          }
        }
      });
      return null;
    }, [metaWindowIdsKey, monitorKey, tileMotionKey]);

    return ClipRect(
      child: DeferredPointerHandler(
        child: Stack(
          key: hostKey,
          clipBehavior: Clip.hardEdge,
          children: [
            for (final popupId in popupIds)
              MetaPopupWidget(metaPopupId: popupId),
          ],
        ),
      ),
    );
  }
}

String _motionKeyFor(WidgetRef ref, MetaWindowId metaWindowId) {
  try {
    final motion = ref.watch(
      metaWindowStateProvider(metaWindowId).select(
        (window) => (
          position: window.position,
          renderOrigin: window.renderOrigin,
          viewport: window.viewport,
        ),
      ),
    );
    return '$metaWindowId:${motion.position}:${motion.renderOrigin}:'
        '${motion.viewport}';
  } catch (_) {
    return '$metaWindowId:?';
  }
}
