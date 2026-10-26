import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'meta_popup.serializable.freezed.dart';
part 'meta_popup.serializable.g.dart';

typedef MetaPopupId = String;

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

    /// Position of the popup surface relative to the parent window box's
    /// top-left corner.
    ///
    /// X11 override-redirect popups are reported at the root and Wayland xdg
    /// popups relative to the toplevel; the compositor normalizes both to this
    /// space. A host tile or floating overlay adds its own parent origin.
    @OffsetConverter() required Offset position,
    @RectConverter() Rect? geometry,
  }) = _MetaPopup;
  factory MetaPopup.fromJson(Map<String, dynamic> json) =>
      _$MetaPopupFromJson(json);
}
