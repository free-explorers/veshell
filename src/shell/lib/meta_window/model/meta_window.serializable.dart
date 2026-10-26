import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/shared/util/json_converter/offset.dart';
import 'package:shell/shared/util/json_converter/rect.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'meta_window.serializable.freezed.dart';
part 'meta_window.serializable.g.dart';

enum MetaWindowDisplayMode { maximized, fullscreen, floating }

typedef MetaWindowId = String;

@freezed
abstract class MetaWindow with _$MetaWindow {
  const factory MetaWindow({
    required MetaWindowId id,
    required int pid,
    required bool mapped,
    required SurfaceId surfaceId,
    required bool needDecoration,
    required bool gameModeActivated,
    required double scaleRatio,

    /// The window's position on the output, for clients that place themselves
    /// (X11). Separate from [geometry], which stays surface-local.
    @OffsetIntConverter() Offset? position,

    /// Whether [position] came from an explicit client placement (an X11
    /// configure request with x/y), rather than the legacy launch origin.
    /// An unplaced floating window is centred; an explicit `(0,0)` is kept.
    @Default(false) bool positionExplicit,

    /// The owning tile's content origin in compositor-global coordinates.
    /// Published by the tile popup host for every display mode.
    @OffsetIntConverter() Offset? tileOrigin,

    /// Compositor-global client-surface origin as rendered by Flutter.
    ///
    /// Unlike [position], this is valid for tiled windows whose native X11
    /// position is synthetic. Popups use it as their parent coordinate base.
    @OffsetIntConverter() Offset? renderOrigin,
    String? appId,
    String? parent,
    String? activatedBy,
    MetaWindowDisplayMode? displayMode,
    String? title,
    String? windowClass,
    String? startupId,
    @Default(false) bool isFixedSized,
    @Default(false) bool isModal,

    /// Client- or shell-negotiated fullscreen state, mirrored from the
    /// compositor. A fullscreen window is treated as a top-level application
    /// surface for routing, not as a dialog.
    @Default(false) bool isFullscreen,

    /// Whether the compositor negotiated a client-maximized state.
    ///
    /// Floating windows reject and clear it; their placement is always the
    /// floating one. This is not the tile's `displayMode`.
    @Default(false) bool clientMaximized,

    /// The global logical viewport of the floating tile, used to clamp native
    /// moves and to translate between the compositor's global space and the
    /// tile-local Flutter space. `null` outside a floating tile.
    ///
    /// Floating ownership is derived from [displayMode]; this is only the
    /// measured viewport, not a second placement flag.
    @RectConverter() Rect? viewport,

    /// Whether the client asked not to be listed in task bars.
    @Default(false) bool skipTaskbar,

    /// Whether the client asked to stay above other windows.
    @Default(false) bool keepOnTop,

    /// Whether a live screen cast is recording this window. Resolved by the
    /// compositor (consumer pid, then app id) and rendered on the tile and its
    /// workspace; the shell never re-derives the mapping.
    @Default(false) bool isRecording,
    String? currentOutput,
    @RectConverter() Rect? geometry,
  }) = _MetaWindow;

  factory MetaWindow.fromJson(Map<String, dynamic> json) =>
      _$MetaWindowFromJson(json);
}

/// The compositor-global placement of a client visible-content box.
///
/// This is the backend-neutral placement shared by Wayland and XWayland:
/// [origin] is the visible-content top-left (the shell decoration is added by
/// Flutter), [clientSize] is the configured client surface size, and
/// [geometryOffset] is the visible-content offset inside the client buffer
/// (nonzero for Wayland CSD shadow margins).
class WindowPlacement {
  const WindowPlacement({
    required this.origin,
    required this.clientSize,
    this.geometryOffset = Offset.zero,
  });

  final Offset origin;
  final Size clientSize;
  final Offset geometryOffset;

  /// The origin pointer coordinates are relative to.
  Offset get surfaceOrigin => origin - geometryOffset;

  /// The client-surface rect in compositor-global coordinates.
  Rect get clientRect => origin & clientSize;
}

extension MetaWindowPlacement on MetaWindow {
  /// The placement represented by [position] and [geometry].
  WindowPlacement? get windowPlacement {
    final position = this.position;
    final geometry = this.geometry;
    if (position == null || geometry == null) {
      return null;
    }
    return WindowPlacement(
      origin: position,
      clientSize: geometry.size,
      geometryOffset: geometry.topLeft,
    );
  }
}

extension MetaWindowSurfaceOrigin on MetaWindow {
  /// The compositor-global origin of the client surface buffer, when this
  /// window is in floating mode.
  ///
  /// [position] addresses the client visible-content box. A Wayland client
  /// with client-side decorations reports a non-zero [geometry] top-left: that
  /// is the visible content offset inside the surface buffer (the CSD shadow
  /// margin). The
  /// buffer itself starts at `position - geometry.topLeft`, which is the origin
  /// pointer coordinates are relative to. X11 reports a zero geometry offset,
  /// so its root position is returned unchanged. Outside floating mode the
  /// shell's render-box basis is authoritative and this returns `null`.
  Offset? get floatingSurfaceOrigin {
    if (displayMode != MetaWindowDisplayMode.floating) {
      return null;
    }
    final placement = windowPlacement;
    if (placement != null) {
      return placement.surfaceOrigin;
    }
    final position = this.position;
    if (position == null) {
      return null;
    }
    return position - (geometry?.topLeft ?? Offset.zero);
  }
}
