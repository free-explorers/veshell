import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'dialog_window_state.g.dart';

/// Workspace provider
@riverpod
class DialogWindowState extends _$DialogWindowState
    with WindowProviderMixin<DialogWindow> {
  @override
  DialogWindow build(DialogWindowId windowId) {
    throw Exception('DialogWindowState $windowId not yet initialized');
  }

  void update(DialogWindow window) {
    state = window;
  }

  @override
  void displayedSurfaceChanged(SurfaceId? surfaceId) {
    if (surfaceId != null) state = state.copyWith(surfaceId: surfaceId);
  }

  @override
  void onDisplayedSurfacePropertiesChanged(WindowProperties windowProperties) {
    state = state.copyWith(properties: windowProperties);
  }
}
