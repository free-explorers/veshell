import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'xdg_toplevel.freezed.dart';

@freezed
class XdgToplevel with _$XdgToplevel {
  /// Factory for XdgToplevel
  const factory XdgToplevel({
    required String? appId,
    required String? title,
    required SurfaceId? parent,
  }) = _XdgToplevel;
}
