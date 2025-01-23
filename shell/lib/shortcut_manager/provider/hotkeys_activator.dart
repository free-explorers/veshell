import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/state/hotkeys_setting.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/model/system_intents.dart';
import 'package:shell/workspace/model/workspace_shortcuts.dart';

part 'hotkeys_activator.g.dart';

enum HotkeysAction {
  increaseVolume('system.increaseVolume'),
  decreaseVolume('system.decreaseVolume'),
  toggleMute('system.muteVolume'),
  focusWorkspaceAbove('screen.focusWorkspaceAbove'),
  focusWorkspaceBelow('screen.focusWorkspaceBelow'),
  focusLeftTileable('workspace.focusLeftTileable'),
  focusRightTileable('workspace.focusRightTileable'),
  closeTileable('workspace.closeTileable');

  const HotkeysAction(this.actionId);
  final String actionId;
}

Intent getActionIntent(HotkeysAction action) => switch (action) {
      HotkeysAction.increaseVolume => const IncreaseVolume(),
      HotkeysAction.decreaseVolume => const DecreaseVolume(),
      HotkeysAction.toggleMute => const ToggleMute(),
      HotkeysAction.focusWorkspaceAbove => const FocusWorkspaceAboveIntent(),
      HotkeysAction.focusWorkspaceBelow => const FocusWorkspaceBelowIntent(),
      HotkeysAction.focusLeftTileable => const FocusLeftTileableIntent(),
      HotkeysAction.focusRightTileable => const FocusRightTileableIntent(),
      HotkeysAction.closeTileable => const CloseTileableIntent(),
    };

@riverpod
class HotkeysActivator extends _$HotkeysActivator {
  @override
  Map<ShortcutActivator, Intent> build() {
    final hotkeysSettings = ref.watch(hotkeysSettingProvider);

    final map = <ShortcutActivator, Intent>{};

    // For each action we check if there is a configured hotkeys recognized
    // fallback to the default one if missing
    for (final action in HotkeysAction.values) {
      final intent = getActionIntent(action);
      final activator = hotkeysSettings[action.actionId];
      if (activator == null) continue;
      map[activator] = intent;
    }
    return map;
  }
}
