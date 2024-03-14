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
    // A X11 surface can be created independently of a Wayland surface,
    // so it needs a different ID space.
    required X11SurfaceId x11SurfaceId,
    // When an X11 surface is mapped, it will be associated with a Wayland surface
    // that will have the role of an X11 surface.
    // This relation is a little bit different from the rest of the Wayland model
    // because it's an aggregation rather than a composition.
    required SurfaceId? surfaceId,
    required bool mapped,
    required bool overrideRedirect,
    @RectConverter() required Rect geometry,
    required X11SurfaceId? parent,
    required IList<X11SurfaceId> children,
    required String title,
    required String windowClass,
    required String instance,
    required String? startupId,
  }) = _X11Surface;
}
