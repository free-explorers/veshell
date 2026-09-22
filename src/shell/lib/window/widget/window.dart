import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/meta_window/widget/meta_surface_gaming_overlay.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/widget/floatable_window.dart';
import 'package:shell/window/widget/window_dialogs.dart';

class WindowWidget extends HookConsumerWidget {
  const WindowWidget({
    required this.metaWindowId,
    required this.focusNode,
    this.displayMode = DisplayMode.maximized,
    this.dialogMetaWindowList = const [],
    super.key,
  });

  final MetaWindowId metaWindowId;
  final DisplayMode displayMode;
  final List<MetaWindowId> dialogMetaWindowList;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activateWindow = useCallback(
      (bool value) {
        final metaWindowToActivate =
            dialogMetaWindowList.lastOrNull ?? metaWindowId;

        final metaWindow =
            ref.read(metaWindowStateProvider(metaWindowToActivate));

        ref.read(platformManagerProvider.notifier).request(
              ActivateWindowRequest(
                message: ActivateWindowMessage(
                  surfaceId: metaWindow.surfaceId,
                  activate: value,
                ),
              ),
            );
      },
      [metaWindowId, dialogMetaWindowList],
    );

    // Re-run the tile sizing effect when the displayed window's geometry
    // changes, so a client that resizes itself away from the tile bounds is
    // pulled back instead of leaving a desynced surface.
    final displayedGeometry = ref.watch(
      metaWindowStateProvider(metaWindowId).select((value) => value.geometry),
    );
    // One corrective patch per observed mismatch: a client that refuses the
    // configure would otherwise be re-patched on every commit it makes.
    final lastCorrectedMismatch = useRef<String?>(null);

    useEffect(
      () {
        if (focusNode.hasFocus) {
          activateWindow(true);
        }
        return null;
      },
      [metaWindowId],
    );

    useEffect(
      () {
        void callback() {
          activateWindow(focusNode.hasFocus);
        }

        focusNode.addListener(callback);
        return () {
          focusNode.removeListener(callback);
        };
      },
      [focusNode],
    );

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
                        if (constraints
                                .widthConstraints()
                                .maxWidth
                                .isInfinite ||
                            constraints
                                .heightConstraints()
                                .maxHeight
                                .isInfinite) {
                          return null;
                        }
                        WidgetsBinding.instance
                            .addPostFrameCallback((timeStamp) {
                          final metaWindow = ref.read(
                            metaWindowStateProvider(metaWindowId),
                          );
                          final geometry = metaWindow.geometry;
                          final targetSize = constraints.biggest;
                          // Measured even when the patch below is a no-op: a
                          // maximized tile must always report the tile bounds
                          // against the window's committed buffer, so a swap of
                          // the displayed meta window is visible in the log.
                          final committedSurfaceSize = ref
                              .read(
                                wlSurfaceStateProvider(metaWindow.surfaceId),
                              )
                              .texture
                              ?.size;

                          geometryLog.info(
                            'sizing tile id=$metaWindowId '
                            'surface=${metaWindow.surfaceId} '
                            'target=$targetSize before=${geometry?.size} '
                            'actual=$committedSurfaceSize '
                            'fixed=${metaWindow.isFixedSized} '
                            'scale=${metaWindow.scaleRatio}',
                          );

                          // A maximized tile owns its size: re-assert the tile
                          // bounds whenever the displayed window reports a
                          // different size (e.g. a client that un-maximized
                          // itself). Fixed-size windows are left alone here;
                          // they are rendered by the fit path instead.
                          final atTarget = geometry != null &&
                              geometry.width == targetSize.width &&
                              geometry.height == targetSize.height;
                          if (atTarget || metaWindow.isFixedSized) {
                            return;
                          }
                          final mismatchSignature =
                              '$metaWindowId|$targetSize|${geometry?.size}';
                          if (lastCorrectedMismatch.value ==
                              mismatchSignature) {
                            return;
                          }
                          lastCorrectedMismatch.value = mismatchSignature;

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
                      [constraints, metaWindowId, displayedGeometry],
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
            if (dialogMetaWindowList.isNotEmpty) ...[
              const Positioned.fill(child: ColoredBox(color: Colors.black38)),
              WindowDialogs(metaWindowIds: dialogMetaWindowList),
            ],
          ],
        ),
      DisplayMode.game => MetaSurfaceGamingOverlay(
          metaWindowId: metaWindowId,
        ),
      DisplayMode.floating => ContainerWithPositionnableChildren(
          children: [
            FloatableWindow(metaWindowId: metaWindowId),
            for (final dialogMetaWindowId in dialogMetaWindowList)
              FloatableWindow(metaWindowId: dialogMetaWindowId),
          ],
        ),
    };
  }
}
