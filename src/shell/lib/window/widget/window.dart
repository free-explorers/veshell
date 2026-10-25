import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/meta_window/widget/meta_surface_gaming_overlay.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';

class WindowWidget extends HookConsumerWidget {
  const WindowWidget({
    required this.metaWindowId,
    required this.focusNode,
    this.displayMode = DisplayMode.maximized,
    this.activationTarget,
    super.key,
  });

  final MetaWindowId metaWindowId;
  final DisplayMode displayMode;
  final FocusNode focusNode;

  /// The window this widget activates when [focusNode] holds the keyboard,
  /// instead of [metaWindowId] itself.
  ///
  /// A tile backed by a dialog area passes the selected dialog: the tile's one
  /// focus node keeps driving activation, and the topmost dialog — not the
  /// window behind it — receives the keyboard, exactly like the old floating
  /// stack raised the newest dialog.
  final MetaWindowId? activationTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaWindowToActivate = activationTarget ?? metaWindowId;
    final activateWindow = useCallback((bool value) {
      // The callback can outlive the window (focus change, leftover effect);
      // reading a destroyed MetaWindowState throws by design.
      final metaWindow = _readMetaWindow(ref, metaWindowToActivate);
      if (metaWindow == null) {
        return;
      }

      ref
          .read(platformManagerProvider.notifier)
          .request(
            ActivateWindowRequest(
              message: ActivateWindowMessage(
                surfaceId: metaWindow.surfaceId,
                activate: value,
              ),
            ),
          );
    }, [metaWindowToActivate]);

    // `metaWindowStateProvider` throws by design until its window is created
    // and after it is destroyed. A tile can briefly outlive the window it
    // points at — a mis-route or a teardown race — and letting that read throw
    // replaces the whole tile, close affordances included, with the error
    // widget: the blank, unclosable tile. Read it defensively and render
    // nothing until the tile re-points (its owner clears `metaWindowId`) or is
    // removed. The dependency is still registered, so the tile recovers if the
    // window reappears under the same id.

    // Re-run the tile sizing effect when the displayed window's committed
    // buffer changes, so a client that resizes itself away from the tile bounds
    // is pulled back instead of leaving a desynced surface. The committed
    // buffer -- not the xdg window geometry -- is what tells us how big the
    // client is actually rendering: a client is not required to re-set its
    // window geometry on resize, so the geometry can lag (or stay stale) while
    // the buffer shrinks, which made restoring the tile count a no-op.
    ({int surfaceId, Rect? geometry, double scaleRatio})? displayedSizing;
    try {
      displayedSizing = ref.watch(
        metaWindowStateProvider(metaWindowId).select(
          (value) => (
            surfaceId: value.surfaceId,
            geometry: value.geometry,
            scaleRatio: value.scaleRatio,
          ),
        ),
      );
    } on Object {
      displayedSizing = null;
    }
    final displayedBufferSize = displayedSizing == null
        ? null
        : ref.watch(
            wlSurfaceStateProvider(
              displayedSizing.surfaceId,
            ).select((value) => value.texture?.size),
          );
    // One corrective patch per observed mismatch: a client that refuses the
    // configure would otherwise be re-patched on every commit it makes. The
    // key is a value type, compared field by field: a string key built from
    // `Size` interpolation is not reliable in release builds (there `Size`
    // stringifies to a constant `Instance of 'Size'`), which made every
    // mismatch look alike and suppressed all corrective patches after the
    // first one.
    final lastCorrectedMismatch = useRef<(String, Size, Size?)?>(null);

    useEffect(() {
      if (focusNode.hasFocus) {
        activateWindow(true);
      }
      return null;
    }, [metaWindowId, activationTarget]);

    useEffect(() {
      void callback() {
        activateWindow(focusNode.hasFocus);
      }

      focusNode.addListener(callback);
      return () {
        focusNode.removeListener(callback);
      };
    }, [focusNode, activateWindow]);

    if (displayedSizing == null) {
      // The native window is gone. Its owner clears `metaWindowId` on the next
      // frame; until then render nothing rather than the error widget.
      return const SizedBox.shrink();
    }

    return switch (displayMode) {
      DisplayMode.maximized ||
      DisplayMode
          .fullscreen => // TODO: fix this, it's not working with the new wayland stack, need to find a way to get the surface id from the meta surface and then use that to get the surface from the wayland stack, or just use the meta surface directly, but that would mean we need to change the way we handle surfaces in flutte
      Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return HookBuilder(
                builder: (context) {
                  useEffect(
                    () {
                      if (constraints.widthConstraints().maxWidth.isInfinite ||
                          constraints
                              .heightConstraints()
                              .maxHeight
                              .isInfinite) {
                        return null;
                      }
                      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                        // The window may have closed between the frame and this
                        // callback; reading its destroyed state throws.
                        final metaWindow = _readMetaWindow(ref, metaWindowId);
                        if (metaWindow == null) {
                          return;
                        }
                        final geometry = metaWindow.geometry;
                        final targetSize = constraints.biggest;
                        // The committed buffer is the surface's actual size,
                        // in physical pixels: divide by the scale to compare
                        // it with the logical tile bounds.
                        final logicalBufferSize = displayedBufferSize == null
                            ? null
                            : Size(
                                displayedBufferSize.width /
                                    metaWindow.scaleRatio,
                                displayedBufferSize.height /
                                    metaWindow.scaleRatio,
                              );

                        geometryLog.info(
                          'sizing tile id=$metaWindowId '
                          'surface=${metaWindow.surfaceId} '
                          'target=${targetSize.width}x${targetSize.height} '
                          'before=${geometry?.width}x${geometry?.height} '
                          'actual='
                          '${logicalBufferSize?.width}x'
                          '${logicalBufferSize?.height} '
                          'fixed=${metaWindow.isFixedSized} '
                          'scale=${metaWindow.scaleRatio}',
                        );

                        // A maximized tile owns its size: re-assert the tile
                        // bounds whenever the committed buffer does not match
                        // them (e.g. a client that un-maximized itself, or a
                        // tile restored from a narrower visible length).
                        // Fixed-size windows are left alone here; they are
                        // rendered by the fit path instead.
                        final atTarget =
                            logicalBufferSize != null &&
                            (logicalBufferSize.width - targetSize.width).abs() <
                                1 &&
                            (logicalBufferSize.height - targetSize.height)
                                    .abs() <
                                1;
                        if (atTarget || metaWindow.isFixedSized) {
                          return;
                        }
                        final mismatchKey = (
                          metaWindowId,
                          targetSize,
                          logicalBufferSize,
                        );
                        if (lastCorrectedMismatch.value == mismatchKey) {
                          return;
                        }
                        lastCorrectedMismatch.value = mismatchKey;

                        ref
                            .read(
                              metaWindowStateProvider(metaWindowId).notifier,
                            )
                            .patch(
                              UpdateGeometry(
                                id: metaWindowId,
                                value: Rect.fromLTWH(
                                  geometry?.left ?? 0,
                                  geometry?.top ?? 0,
                                  targetSize.width,
                                  targetSize.height,
                                ),
                              ),
                            );
                      });
                      return null;
                    },
                    [
                      constraints,
                      metaWindowId,
                      displayedSizing,
                      displayedBufferSize,
                    ],
                  );

                  return MetaSurfaceWidget(
                    focusNode: focusNode,
                    metaWindowId: metaWindowId,
                    decorated: false,
                  );
                },
              );
            },
          ),
        ],
      ),
      DisplayMode.game => MetaSurfaceGamingOverlay(metaWindowId: metaWindowId),
      DisplayMode.floating => throw StateError(
        'DisplayMode.floating is rendered by FloatingWindowArea',
      ),
    };
  }
}

/// Reads the state of [metaWindowId], or `null` when the shell no longer tracks
/// that window.
///
/// [metaWindowStateProvider] throws by design until its window is created and
/// after it is destroyed. A tile can briefly outlive the window it points at
/// (a mis-route or a teardown race), so any read that could run after the
/// window is gone goes through here instead of crashing the caller.
MetaWindow? _readMetaWindow(WidgetRef ref, MetaWindowId metaWindowId) {
  try {
    return ref.read(metaWindowStateProvider(metaWindowId));
  } on Object {
    return null;
  }
}
