import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'platform_focused_view.g.dart';

/// The compositor's platform focus source of truth: the id of the output view
/// that currently owns platform focus.
///
/// The compositor updates this whenever the pointer moves onto another view
/// (or the engine asks to move keyboard focus across views), independent of
/// Flutter's widget focus quirks. `null` until the compositor first reports a
/// focused view.
@riverpod
class PlatformFocusedViewId extends _$PlatformFocusedViewId {
  @override
  int? build() => null;

  /// Records the view the compositor reported as focused.
  void set(int? viewId) {
    if (state == viewId) {
      return;
    }
    state = viewId;
  }
}
