import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/config_directory.dart';
import 'package:shell/settings/provider/default_config_directory.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/model/string_to_key.dart';
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
    final configDirectory = ref.watch(configDirectoryProvider);
    final defaultConfigDirectory = ref.watch(defaultConfigDirectoryProvider);

    final hotkeyConfigFile = File('${configDirectory.path}/hotkeys.json');
    final configurationJson = jsonDecode(
      hotkeyConfigFile.existsSync()
          ? hotkeyConfigFile.readAsStringSync()
          : '{}',
    ) as Map<String, dynamic>;

    final defaultJson = jsonDecode(
      File('${defaultConfigDirectory.path}/hotkeys.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final map = <ShortcutActivator, Intent>{};

    // For each action we check if there is a configured hotkeys recognized
    // fallback to the default one if missing
    for (final action in HotkeysAction.values) {
      final intent = getActionIntent(action);
      final activator = getKeysetFromJson(action.actionId, configurationJson) ??
          getKeysetFromJson(action.actionId, defaultJson);
      if (activator == null) {
        print('Missing hotkey for action: ${action.actionId} in default file');
        continue;
      }
      map[activator] = intent;
    }
    return map;
  }
}

LogicalKeySet? getKeysetFromJson(String actionId, Map<String, dynamic> json) {
  if (!json.containsKey(actionId)) return null;
  final keysString = (json[actionId]! as String).split('+');
  final keys = keysString.map(
    (e) => stringToKeyMap[e],
  );
  if (keys.contains(null)) return null;

  return LogicalKeySet.fromSet(keys.cast<LogicalKeyboardKey>().toSet());
}
