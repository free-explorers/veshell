import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_popup.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_state.dart';
import 'package:shell/shared/util/snapping.dart';
import 'package:shell/wayland/widget/surface.dart';

class MetaPopupWidget extends HookConsumerWidget {
  const MetaPopupWidget({
    required this.metaPopupId,
    this.parentOrigin = Offset.zero,
    this.coordinateOffset = Offset.zero,
    super.key,
  });

  final MetaPopupId metaPopupId;

  /// Compositor-global origin of the popup parent's window box.
  ///
  /// [MetaPopup.position] is stored relative to that box for both backends, so
  /// a popup rendered outside the parent's own surface stack (the floating
  /// tile overlay) must add it back before subtracting the overlay origin.
  final Offset parentOrigin;

  /// Origin of the overlay that hosts the popup, in compositor-global
  /// coordinates.
  ///
  /// A popup rendered in a tile-level overlay must subtract the overlay's own
  /// compositor origin, or it is offset by the workspace/sidebar and its
  /// pointer coordinates are mapped as if it were somewhere else.
  final Offset coordinateOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaPopup = ref.watch(metaPopupStateProvider(metaPopupId));
    // Keep the popup on the whole-pixel grid: a fractional origin would make
    // Flutter sample its external texture bilinearly and soften it (see
    // `snapToWholePixel`).
    //
    // A maximized MetaWindow is undecorated: the SSD title bar is only used by
    // dialogs. Do not add its height to popup positions here.
    final position = snapOffsetToWholePixels(
      metaPopup.position +
          parentOrigin -
          Offset(metaPopup.geometry?.left ?? 0, metaPopup.geometry?.top ?? 0) -
          coordinateOffset,
    );
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: SurfaceWidget(
        surfaceId: metaPopup.surfaceId,
        scaleRatio: metaPopup.scaleRatio,
      ),
    );
  }
}

/* class _Positioner extends HookConsumerWidget {
  const _Positioner({
    required this.surfaceId,
    required this.child,
  });

  final SurfaceId surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const offset = Offset.zero;

    // Sum recursively positions until we reach the toplevel.
    while (ref.read(wlSurfaceStateProvider(id)).role == SurfaceRole.xdgPopup) {
      final popup = xdgPopupStateProvider(id);
      offset += ref.watch(popup.select((popup) => popup.position));
      // Change the origin of the popup to its visible bounds top left corner.
      offset -= _getVisibleBoundsTopLeft(ref, id);
      id = ref.watch(popup.select((popup) => popup.parent));
      // Position the popup relative to its parent's visible bounds top left
      // corner.
      offset += _getVisibleBoundsTopLeft(ref, id);
    }

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: child,
    );
  } */

/*   Offset _getVisibleBoundsTopLeft(WidgetRef ref, SurfaceId id) {
    final geometry = ref.watch(
      xdgSurfaceStateProvider(id).select((xdgSurface) => xdgSurface.geometry),
    );
    return geometry?.topLeft ?? Offset.zero;
  } 
 }
  */
