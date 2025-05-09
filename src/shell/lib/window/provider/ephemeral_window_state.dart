import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/wayland/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'ephemeral_window_state.g.dart';

/// Workspace provider
@riverpod
class EphemeralWindowState extends _$EphemeralWindowState
    with WindowProviderMixin<EphemeralWindow> {
  late MatchingInfo _matchingInfo;

  @override
  EphemeralWindow build(EphemeralWindowId windowId) {
    throw Exception('EphemeralWindowState $windowId not yet initialized');
  }

  @override
  MatchingInfo getMatchingInfo() => _matchingInfo;

  @override
  void initialize(EphemeralWindow window) {
    _matchingInfo = MatchingInfo.fromWindowProperties(
      window.properties,
    );
    super.initialize(window);
  }

  @override
  Future<Process?> launchSelf() async {
    final process = await super.launchSelf();
    if (process != null) {
      waitForSurface(process.pid);
    }
    return process;
  }

  @override
  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId) {
    state = state.copyWith(
      metaWindowId: metaWindowId,
    );

    ref.read(metaWindowStateProvider(metaWindowId!).notifier).patch(
          MetaWindowPatchMessage.updateDisplayMode(
            id: metaWindowId,
            value: MetaWindowDisplayMode.maximized,
          ),
        );
  }

  @override
  void onMetaWindowDisplayedPropertiesChanged(MetaWindow metaWindow) {
    state = state.copyWith(
      properties: WindowProperties.fromMetaWindow(metaWindow),
    );
  }
}
