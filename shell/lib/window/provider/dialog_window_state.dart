import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'dialog_window_state.g.dart';

/// Workspace provider
@riverpod
class DialogWindowState extends _$DialogWindowState with WindowProviderMixin {
  KeepAliveLink? _keepAliveLink;

  @override
  DialogWindow build(DialogWindowId windowId) {
    throw Exception('DialogWindowState $windowId not yet initialized');
  }

  void initialize(DialogWindow window) {
    _keepAliveLink?.close();
    _keepAliveLink = ref.keepAlive();

    state = window;
    syncWithSurface();
  }

  @override
  void onSurfaceChanged(WindowPropertiesState next) {
    state = state.copyWith(appId: next.appId, title: next.title);
  }

  @override
  void onSurfaceIsDestroyed() {
    _keepAliveLink?.close();
    super.onSurfaceIsDestroyed();
  }

  void update(DialogWindow window) {
    state = window;
  }
}
