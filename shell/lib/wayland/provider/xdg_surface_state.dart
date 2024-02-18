import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/xdg_surface.dart';
import 'package:shell/wayland/provider/xdg_popup_state.dart';

part 'xdg_surface_state.g.dart';

@riverpod
class XdgSurfaceState extends _$XdgSurfaceState {
  late final KeepAliveLink _keepAliveLink;

  @override
  XdgSurface build(SurfaceId surfaceId) {
    throw Exception('XdgSurface $surfaceId state was not initialized');
  }

  void initialize({
    required Rect? geometry,
  }) {
    _keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      print('disposing XdgSurfaceStateProvider $surfaceId');
    });
    state = XdgSurface(
      geometry: geometry,
      popups: [],
    );
  }

  void commit({
    required Rect? geometry,
  }) {
    state = state.copyWith(
      geometry: geometry,
    );
    // _checkIfMapped();
  }

  void addPopup(SurfaceId surfaceId) {
    state = state.copyWith(popups: [...state.popups, surfaceId]);
    ref.read(xdgPopupStateProvider(surfaceId).notifier).setParent(surfaceId);
  }

  void removePopup(SurfaceId surfaceId) {
    state = state.copyWith(
      popups: [
        for (final int id in state.popups)
          if (id != surfaceId) id,
      ],
    );
  }

// void dispose() {
//   switch (state.role) {
//     case SurfaceRole.xdgTopLevel:
//       ref.read(xdgToplevelStatesProvider(surfaceId).notifier).dispose();
//     case SurfaceRole.xdgPopup:
//       ref.read(xdgPopupStatesProvider(surfaceId).notifier).dispose();
//     case SurfaceRole.subsurface:
//     case SurfaceRole.none:
//     case SurfaceRole.cursorImage:
//       break;
//   }
//   ref.invalidate(xdgSurfaceStatesProvider(surfaceId));
// }
//
// void _checkIfMapped() {
//   final mapped = state.role != SurfaceRole.none &&
//           ref.read(wlSurfaceStateProvider(surfaceId)).textureId != -1 &&
//           ref.read(wlSurfaceStateProvider(surfaceId)).role ==
//               SurfaceRole.xdgPopup ||
//       ref.read(wlSurfaceStateProvider(surfaceId)).role ==
//           SurfaceRole.xdgTopLevel;
//
//   final wasMapped = state.mapped;
//   state = state.copyWith(
//     mapped: mapped,
//   );
//
//   if (!wasMapped && mapped) {
//     _map();
//   } else if (wasMapped && !mapped) {
//     _unmap();
//   }
// }
//
// void _map() {
//   final role = state.role;
//
//   switch (role) {
//     case SurfaceRole.xdgTopLevel:
//       ref.read(platformApiProvider).windowMappedSink.add(surfaceId);
//
//     case SurfaceRole.xdgPopup:
//       final widgetExists = ref
//               .read(xdgPopupStatesProvider(surfaceId))
//               .animationsKey
//               .currentWidget !=
//           null;
//       if (widgetExists) {
//         ref
//             .read(xdgPopupStatesProvider(surfaceId).notifier)
//             .cancelClosingAnimation();
//       } else {
//         ref.read(popupStackChildrenProvider.notifier).add(surfaceId);
//       }
//
//     case SurfaceRole.subsurface:
//     case SurfaceRole.none:
//     case SurfaceRole.cursorImage:
//       if (kDebugMode) {
//         assert(false);
//       }
//   }
// }
//
// Future<void> _unmap() async {
//   final role = state.role;
//   switch (role) {
//     case SurfaceRole.subsurface:
//     case SurfaceRole.none:
//     case SurfaceRole.cursorImage:
//       if (kDebugMode) {
//         assert(false);
//       }
//
//     case SurfaceRole.xdgTopLevel:
//       ref.read(platformApiProvider).windowUnmappedSink.add(surfaceId);
//
//     case SurfaceRole.xdgPopup:
//       // This future will never complete if the animation is canceled.
//       await ref
//           .read(xdgPopupStatesProvider(surfaceId).notifier)
//           .animateClosing();
//       ref.read(popupStackChildrenProvider.notifier).remove(surfaceId);
//   }
// }
}
