import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/common/popup_stack.dart';
import 'package:zenith/ui/common/state/xdg_popup_state.dart';
import 'package:zenith/ui/common/state/xdg_toplevel_state.dart';

part '../../../generated/ui/common/state/xdg_surface_state.freezed.dart';
part '../../../generated/ui/common/state/xdg_surface_state.g.dart';

@freezed
class XdgSurfaceState with _$XdgSurfaceState {
  const factory XdgSurfaceState({
    required XdgSurfaceRole role,
    required bool mapped,
    required Rect visibleBounds,
    required GlobalKey widgetKey,
    required List<int> popups,
  }) = _XdgSurfaceState;
}

@Riverpod(keepAlive: true)
class XdgSurfaceStates extends _$XdgSurfaceStates {
  @override
  XdgSurfaceState build(int viewId) {
    return XdgSurfaceState(
      role: XdgSurfaceRole.none,
      mapped: false,
      visibleBounds: Rect.zero,
      widgetKey: GlobalKey(),
      popups: [],
    );
  }

  void _mapXdgSurface(dynamic event) {
    int viewId = event["view_id"];

    XdgSurfaceRole role = state.role;

    switch (role) {
      case XdgSurfaceRole.none:
        if (kDebugMode) {
          assert(false);
        }
        break;

      case XdgSurfaceRole.toplevel:
        ref.read(platformApiProvider).windowMappedSink.add(viewId);
        break;

      case XdgSurfaceRole.popup:
        bool widgetExists = ref.read(xdgPopupStatesProvider(viewId)).animationsKey.currentWidget != null;
        if (widgetExists) {
          ref.read(xdgPopupStatesProvider(viewId).notifier).cancelClosingAnimation();
        } else {
          ref.read(popupStackChildrenProvider.notifier).add(viewId);
        }
        break;
    }
  }

  void _unmapXdgSurface(dynamic event) async {
    int viewId = event["view_id"];

    XdgSurfaceRole role = state.role;
    switch (role) {
      case XdgSurfaceRole.none:
        if (kDebugMode) {
          assert(false);
        }
        break;

      case XdgSurfaceRole.toplevel:
        ref.read(platformApiProvider).windowUnmappedSink.add(viewId);
        break;

      case XdgSurfaceRole.popup:
        // This future will never complete if the animation is canceled.
        await ref.read(xdgPopupStatesProvider(viewId).notifier).animateClosing();
        ref.read(popupStackChildrenProvider.notifier).remove(viewId);
        break;
    }
  }

  void commit({
    required XdgSurfaceRole role,
    required bool mapped,
    required Rect visibleBounds,
  }) {
    bool mappedChanged = mapped != state.mapped;
    state = state.copyWith(
      role: role,
      mapped: mapped,
      visibleBounds: visibleBounds,
    );
    if (mappedChanged) {
      if (mapped) {
        _mapXdgSurface({"view_id": viewId});
      } else {
        _unmapXdgSurface({"view_id": viewId});
      }
    }
  }

  void unmap() {
    bool wasMapped = state.mapped;
    state = state.copyWith(
      mapped: false,
    );
    if (wasMapped) {
      _unmapXdgSurface({"view_id": viewId});
    }
  }

  void addPopup(int viewId) {
    state = state.copyWith(popups: [...state.popups, viewId]);
    ref.read(xdgPopupStatesProvider(viewId).notifier).parentViewId = this.viewId;
  }

  void removePopup(int viewId) {
    state = state.copyWith(popups: [
      for (int id in state.popups)
        if (id != viewId) id
    ]);
  }

  void dispose() {
    switch (state.role) {
      case XdgSurfaceRole.toplevel:
        ref.read(xdgToplevelStatesProvider(viewId).notifier).dispose();
        break;
      case XdgSurfaceRole.popup:
        ref.read(xdgPopupStatesProvider(viewId).notifier).dispose();
        break;
      case XdgSurfaceRole.none:
        break;
    }
    ref.invalidate(xdgSurfaceStatesProvider(viewId));
  }
}

enum XdgSurfaceRole {
  none,
  toplevel,
  popup,
}
