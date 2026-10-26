import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'meta_popup.serializable.freezed.dart';
part 'meta_popup.serializable.g.dart';

typedef MetaPopupId = String;

/// The tile-content placement of a popup's client surface.
///
/// [origin] is the popup box origin relative to the owning tile's content
/// origin; [geometryOffset] is the surface-local offset inside the popup
/// buffer. This mirrors [WindowPlacement] with the tile as the anchor.
class PopupPlacement {
  const PopupPlacement({
    required this.origin,
    this.geometryOffset = Offset.zero,
  });

  final Offset origin;
  final Offset geometryOffset;

  /// The origin pointer coordinates are relative to.
  Offset get surfaceOrigin => origin - geometryOffset;
}

enum MetaPopupCategory {
  /// A regular client popup that should be rendered as UI.
  popup,

  /// A menu, dropdown, combo or other interactive menu popup.
  menu,

  /// A tooltip-like popup. Some X11 clients use this type for floating
  /// panels, so it is not hidden by default.
  tooltip,

  /// A non-visible or non-interactive backing window owned by the client.
  /// The shell keeps it in the model for focus/bookkeeping but does not
  /// render it as a popup surface.
  helper,
}

@freezed
abstract class MetaPopup with _$MetaPopup {
  const factory MetaPopup({
    required MetaPopupId id,
    required MetaWindowId parent,
    @Default(MetaPopupCategory.popup) MetaPopupCategory category,
    required SurfaceId surfaceId,
    required double scaleRatio,

    /// Position of the popup surface relative to the owning tile's content
    /// origin.
    ///
    /// X11 override-redirect popups are reported at the root and Wayland xdg
    /// popups relative to the parent; the compositor normalizes both to this
    /// space. The tile popup host renders directly in it, so a parent window
    /// move never translates an X11 popup.
    @OffsetConverter() required Offset position,
    @RectConverter() Rect? geometry,
  }) = _MetaPopup;
  factory MetaPopup.fromJson(Map<String, dynamic> json) =>
      _$MetaPopupFromJson(json);
}

extension MetaPopupPlacement on MetaPopup {
  /// The placement represented by [position] and [geometry].
  PopupPlacement get placement => PopupPlacement(
    origin: position,
    geometryOffset: geometry?.topLeft ?? Offset.zero,
  );
}
