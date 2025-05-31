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
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/widget/floatable_window.dart';

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
                          final geometry = ref.read(
                            metaWindowStateProvider(metaWindowId)
                                .select((value) => value.geometry),
                          );

                          print('debug1 geometry: $geometry');

                          ref
                              .read(
                                metaWindowStateProvider(metaWindowId).notifier,
                              )
                              .patch(
                                UpdateGeometry(
                                  id: metaWindowId,
                                  value: Rect.fromLTWH(
                                    geometry!.left,
                                    geometry.top,
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                ),
                              );
                        });
                        return null;
                      },
                      [constraints],
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
              ContainerWithPositionnableChildren(
                children: dialogMetaWindowList
                    .map(
                      (e) => FloatableWindow(
                        metaWindowId: e,
                      ),
                    )
                    .toList(),
              ),
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
