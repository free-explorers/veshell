import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/common/state/xdg_surface_state.dart';
import 'package:zenith/ui/common/xdg_toplevel_surface.dart';

part '../../../generated/ui/common/state/xdg_toplevel_state.freezed.dart';

part '../../../generated/ui/common/state/xdg_toplevel_state.g.dart';

@Riverpod(keepAlive: true)
XdgToplevelSurface xdgToplevelSurfaceWidget(XdgToplevelSurfaceWidgetRef ref, int viewId) {
  return XdgToplevelSurface(
    key: ref.watch(xdgSurfaceStatesProvider(viewId).select((state) => state.widgetKey)),
    viewId: viewId,
  );
}

@freezed
class XdgToplevelState with _$XdgToplevelState {
  const factory XdgToplevelState({
    required bool visible,
    required Key virtualKeyboardKey,
    required FocusNode focusNode,
    required Object interactiveMoveRequested,
    required ResizeEdgeObject interactiveResizeRequested,
    required ToplevelDecoration decoration,
    required String title,
    required String appId,
    required Tiling? tilingRequested,
  }) = _XdgToplevelState;
}

@Riverpod(keepAlive: true)
class XdgToplevelStates extends _$XdgToplevelStates {
  @override
  XdgToplevelState build(int viewId) {
    final focusNode = FocusNode();
    focusNode.addListener(() {
      final platformApi = ref.read(platformApiProvider.notifier);
      if (focusNode.hasFocus) {
        platformApi.activateWindow(viewId, true);
      } else {
        platformApi.activateWindow(viewId, false);
      }
    });

    ref.onDispose(() {
      // Access focusNode and not state.focusNode because we cannot access `state` inside onDispose.
      focusNode.dispose();
    });

    return XdgToplevelState(
      visible: true,
      virtualKeyboardKey: GlobalKey(),
      focusNode: focusNode,
      interactiveMoveRequested: Object(),
      interactiveResizeRequested: ResizeEdgeObject(ResizeEdge.top),
      decoration: ToplevelDecoration.none,
      title: "",
      appId: "",
      tilingRequested: null,
    );
  }

  set visible(bool value) {
    if (value != state.visible) {
      ref.read(platformApiProvider.notifier).changeWindowVisibility(viewId, value);
      state = state.copyWith(visible: value);
    }
  }

  void requestMaximize(bool maximize) {
    state = state.copyWith(
      tilingRequested: maximize ? Tiling.maximized : Tiling.none,
    );
  }

  void maximize(bool value) {
    ref.read(platformApiProvider.notifier).maximizeWindow(viewId, value);
  }

  void resize(int width, int height) {
    ref.read(platformApiProvider.notifier).resizeWindow(viewId, width, height);
  }

  void requestInteractiveMove() {
    state = state.copyWith(
      interactiveMoveRequested: Object(),
    );
  }

  void requestInteractiveResize(ResizeEdge edge) {
    state = state.copyWith(
      interactiveResizeRequested: ResizeEdgeObject(edge),
    );
  }

  void setDecoration(ToplevelDecoration decoration) {
    state = state.copyWith(
      decoration: decoration,
    );
  }

  void setTitle(String title) {
    state = state.copyWith(
      title: title,
    );
  }

  void setAppId(String appId) {
    state = state.copyWith(
      appId: appId,
    );
  }

  void dispose() {
    ref.invalidate(xdgToplevelSurfaceWidgetProvider(viewId));
    ref.invalidate(xdgToplevelStatesProvider(viewId));
  }
}

enum ResizeEdge {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left;

  static ResizeEdge fromInt(int n) {
    switch (n) {
      case 1:
        return top;
      case 2:
        return bottom;
      case 4:
        return left;
      case 5:
        return topLeft;
      case 6:
        return bottomLeft;
      case 8:
        return right;
      case 9:
        return topRight;
      case 10:
        return bottomRight;
      default:
        return bottomRight;
    }
  }
}

class ResizeEdgeObject {
  final ResizeEdge edge;

  ResizeEdgeObject(this.edge);
}

enum ToplevelDecoration {
  none,
  clientSide,
  serverSide;

  static ToplevelDecoration fromInt(int n) {
    switch (n) {
      case 0:
        return none;
      case 1:
        return clientSide;
      case 2:
        return serverSide;
      default:
        return none;
    }
  }
}

enum Tiling {
  none,
  maximized,
}
