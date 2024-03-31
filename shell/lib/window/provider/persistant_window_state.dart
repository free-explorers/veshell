import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/persistence/persistable_provider.mixin.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'persistant_window_state.g.dart';

/// Workspace provider
@riverpod
class PersistentWindowState extends _$PersistentWindowState
    with
        WindowProviderMixin,
        PersistableProvider<PersistentWindow,
            AutoDisposeNotifierProviderRef<PersistentWindow>> {
  @override
  String getPersistentFolder() => 'Window';

  @override
  String getPersistentId() => windowId.toString();
  @override
  PersistentWindow build(PersistentWindowId windowId) {
    final window = getPersisted(PersistentWindow.fromJson)
        ?.copyWith(isWaitingForSurface: false, surfaceId: null);

    if (window != null) {
      initialize(window);
      return window;
    }
    throw Exception('PersistentWindowState $windowId not yet initialized');
  }

  void initialize(PersistentWindow window) {
    persistChanges();
    state = window;
    syncWithSurface();
  }

  @override
  void onSurfaceChanged(WindowPropertiesState next) {
    state = state.copyWith(appId: next.appId, title: next.title);
  }

  @override
  void onSurfaceIsDestroyed() {
    super.onSurfaceIsDestroyed();
    state = state.copyWith(surfaceId: null);
  }

  void update(PersistentWindow window) {
    state = window;
  }
}
