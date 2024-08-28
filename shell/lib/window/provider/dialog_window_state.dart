import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'dialog_window_state.g.dart';

/// Workspace provider
@riverpod
class DialogWindowState extends _$DialogWindowState with WindowProviderMixin {
  @override
  DialogWindow build(DialogWindowId windowId) {
    throw Exception('DialogWindowState $windowId not yet initialized');
  }

  @override
  void onSurfaceChanged(WindowProperties next) {
    state = state.copyWith(properties: next);
  }

  void update(DialogWindow window) {
    state = window;
  }
}
