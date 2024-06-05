import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'x11_surface.freezed.dart';

typedef X11SurfaceId = int;

@freezed
class X11Surface with _$X11Surface {
  const factory X11Surface({
    /// A X11 surface can be created independently of a Wayland surface,
    /// so it needs a different ID space.
    required X11SurfaceId x11SurfaceId,

    /// When an X11 surface is mapped (x11Mapped == true),
    /// it will be associated with a Wayland surface that will have the role of
    /// an X11 surface.
    /// This relation is a little bit different from the rest of the Wayland model
    /// because it's an aggregation rather than a composition.
    required SurfaceId? surfaceId,

    /// Use this property to know if you should display this surface.
    /// It's true when the surface is marked mapped by X11
    /// and a texture is bound to the Wayland surface.
    required bool mapped,

    /// If true, the window manager should:
    /// - Obey the geometry property i.e. the window should be placed and sized
    /// how the client requested.
    /// - Not show it in the task bar like a normal window.
    ///
    /// This property is normally set to true for popups and tooltips.
    required bool overrideRedirect,

    /// The position and size of the surface where the client wants it to be
    /// displayed.
    @RectConverter() required Rect geometry,
    required X11SurfaceId? parent,
    required IList<X11SurfaceId> children,
    required String? title,
    required String? windowClass,
    required String? instance,
    required String? startupId,
  }) = _X11Surface;
}
