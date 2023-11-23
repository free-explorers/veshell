import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/platform_api/platform_api.provider.dart';
import 'package:shell/manager/platform_api/platform_event.model.serializable.dart';
import 'package:shell/shared/wayland/surface/surface.provider.dart';
import 'package:shell/shared/wayland/xdg_popup/xdg_popup.provider.dart';
import 'package:shell/shared/wayland/xdg_surface/xdg_surface.model.dart';
import 'package:shell/shared/wayland/xdg_toplevel/xdg_toplevel.provider.dart';

part 'xdg_surface.provider.g.dart';

@Riverpod(keepAlive: true)
class XdgSurfaceStates extends _$XdgSurfaceStates {
  @override
  XdgSurfaceState build(int viewId) {
    ref.listen(
      surfaceStatesProvider(viewId)
          .select((state) => (state.textureId, state.role)),
      (_, __) => _checkIfMapped(),
    );

    return XdgSurfaceState(
      mapped: false,
      role: XdgSurfaceRole.none,
      visibleBounds: Rect.zero,
      widgetKey: GlobalKey(),
      popups: [],
    );
  }

  void commit({
    required XdgSurfaceRole role,
    required Rect visibleBounds,
  }) {
    state = state.copyWith(
      role: role,
      visibleBounds: visibleBounds,
    );
    _checkIfMapped();
  }

  void addPopup(int viewId) {
    state = state.copyWith(popups: [...state.popups, viewId]);
    ref.read(xdgPopupStatesProvider(viewId).notifier).parentViewId =
        this.viewId;
  }

  void removePopup(int viewId) {
    state = state.copyWith(
      popups: [
        for (int id in state.popups)
          if (id != viewId) id
      ],
    );
  }

  void dispose() {
    switch (state.role) {
      case XdgSurfaceRole.toplevel:
        ref.read(xdgToplevelStatesProvider(viewId).notifier).dispose();
      case XdgSurfaceRole.popup:
        ref.read(xdgPopupStatesProvider(viewId).notifier).dispose();
      case XdgSurfaceRole.none:
        break;
    }
    ref.invalidate(xdgSurfaceStatesProvider(viewId));
  }

  void _checkIfMapped() {
    final mapped = state.role != XdgSurfaceRole.none &&
        ref.read(surfaceStatesProvider(viewId)).textureId.value != -1 &&
        ref.read(surfaceStatesProvider(viewId)).role == SurfaceRole.xdgSurface;

    final wasMapped = state.mapped;
    state = state.copyWith(
      mapped: mapped,
    );

    if (!wasMapped && mapped) {
      _map();
    } else if (wasMapped && !mapped) {
      _unmap();
    }
  }

  void _map() {
    final role = state.role;

    switch (role) {
      case XdgSurfaceRole.none:
        if (kDebugMode) {
          assert(false);
        }

      case XdgSurfaceRole.toplevel:
        ref.read(platformApiProvider).windowMappedSink.add(viewId);

      case XdgSurfaceRole.popup:
        final widgetExists = ref
                .read(xdgPopupStatesProvider(viewId))
                .animationsKey
                .currentWidget !=
            null;
        if (widgetExists) {
          ref
              .read(xdgPopupStatesProvider(viewId).notifier)
              .cancelClosingAnimation();
        } else {
          ref.read(popupStackChildrenProvider.notifier).add(viewId);
        }
    }
  }

  Future<void> _unmap() async {
    final role = state.role;
    switch (role) {
      case XdgSurfaceRole.none:
        if (kDebugMode) {
          assert(false);
        }

      case XdgSurfaceRole.toplevel:
        ref.read(platformApiProvider).windowUnmappedSink.add(viewId);

      case XdgSurfaceRole.popup:
        // This future will never complete if the animation is canceled.
        await ref
            .read(xdgPopupStatesProvider(viewId).notifier)
            .animateClosing();
        ref.read(popupStackChildrenProvider.notifier).remove(viewId);
    }
  }
}
