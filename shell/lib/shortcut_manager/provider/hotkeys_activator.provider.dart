import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/model/string_to_key.dart';
import 'package:shell/shortcut_manager/model/system_intents.dart';
import 'package:shell/workspace/model/workspace_shortcuts.dart';

part 'hotkeys_activator.provider.g.dart';

final actionIdToIntentMap = {
  'system.increaseVolume': const IncreaseVolume(),
  'system.decreaseVolume': const DecreaseVolume(),
  'system.muteVolume': const ToggleMute(),
  'screen.focusWorkspaceAbove': const FocusWorkspaceAboveIntent(),
  'screen.focusWorkspaceBelow': const FocusWorkspaceBelowIntent(),
  'workspace.focusLeftTileable': const FocusLeftTileableIntent(),
  'workspace.focusRightTileable': const FocusRightTileableIntent(),
  'workspace.closeTileable': const CloseTileableIntent(),
};

@riverpod
class HotkeysActivator extends _$HotkeysActivator {
  @override
  Map<ShortcutActivator, Intent> build() {
    final testJson = {
      'system.increaseVolume': 'volumeUp',
      'system.decreaseVolume': 'volumeDown',
      'system.muteVolume': 'ctrl+alt+m',
      'screen.focusWorkspaceAbove': 'super+w',
      'screen.focusWorkspaceBelow': 'super+s',
      'workspace.focusLeftTileable': 'super+a',
      'workspace.focusRightTileable': 'super+d',
      'workspace.closeTileable': 'super+q',
    };
    final map = <ShortcutActivator, Intent>{};
    testJson.forEach((key, value) {
      final intent = actionIdToIntentMap[key];
      if (intent == null) {
        return;
      }
      final keysString = value.split('+');
      final keys = keysString.map(
        (e) => stringToKeyMap[e],
      );
      if (keys.contains(null)) {
        return;
      }
      final activator = LogicalKeySet.fromSet(keys.whereNotNull().toSet());
      map[activator] = intent;
    });
    return map;
  }
}
