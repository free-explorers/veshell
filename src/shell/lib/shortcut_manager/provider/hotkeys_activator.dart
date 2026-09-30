import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/state/hotkeys_setting.dart';
import 'package:shell/shortcut_manager/model/media_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/model/system_intents.dart';
import 'package:shell/workspace/model/workspace_shortcuts.dart';

part 'hotkeys_activator.g.dart';

enum HotkeysAction {
  increaseVolume('system.increaseVolume'),
  decreaseVolume('system.decreaseVolume'),
  toggleMute('system.muteVolume'),
  mediaPlayPause('media.playPause'),
  mediaNext('media.next'),
  mediaPrevious('media.previous'),
  mediaStop('media.stop'),
  focusWorkspaceAbove('screen.focusWorkspaceAbove'),
  focusWorkspaceBelow('screen.focusWorkspaceBelow'),
  reorderWorkspaceAbove('screen.reorderWorkspaceAbove'),
  reorderWorkspaceBelow('screen.reorderWorkspaceBelow'),
  focusLeftTileable('workspace.focusLeftTileable'),
  focusRightTileable('workspace.focusRightTileable'),
  reorderLeftTileable('workspace.reorderLeftTileable'),
  reorderRightTileable('workspace.reorderRightTileable'),
  closeTileable('workspace.closeTileable');

  const HotkeysAction(this.actionId);
  final String actionId;
}

Intent getActionIntent(HotkeysAction action) => switch (action) {
  HotkeysAction.increaseVolume => const IncreaseVolume(),
  HotkeysAction.decreaseVolume => const DecreaseVolume(),
  HotkeysAction.toggleMute => const ToggleMute(),
  HotkeysAction.mediaPlayPause => const MediaPlayPauseIntent(),
  HotkeysAction.mediaNext => const MediaNextIntent(),
  HotkeysAction.mediaPrevious => const MediaPreviousIntent(),
  HotkeysAction.mediaStop => const MediaStopIntent(),
  HotkeysAction.focusWorkspaceAbove => const FocusWorkspaceAboveIntent(),
  HotkeysAction.focusWorkspaceBelow => const FocusWorkspaceBelowIntent(),
  HotkeysAction.reorderWorkspaceAbove => const ReorderWorkspaceAboveIntent(),
  HotkeysAction.reorderWorkspaceBelow => const ReorderWorkspaceBelowIntent(),
  HotkeysAction.focusLeftTileable => const FocusLeftTileableIntent(),
  HotkeysAction.focusRightTileable => const FocusRightTileableIntent(),
  HotkeysAction.reorderLeftTileable => const ReorderLeftTileableIntent(),
  HotkeysAction.reorderRightTileable => const ReorderRightTileableIntent(),
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
      // `LogicalKeySet.fromSet({})` matches every key event, so guard against
      // empty bindings as well as missing ones.
      if (activator == null || activator.keys.isEmpty) continue;
      map[activator] = intent;
    }

    // Some keyboards report the play/pause button as `XF86AudioPlay` (or
    // `XF86AudioPause`) instead of `XF86AudioPlayPause`; Flutter then yields
    // `mediaPlay`/`mediaPause` rather than `mediaPlayPause`. When
    // `media.playPause` is bound to any of those keys, accept the whole family
    // so the hardware button works whichever name the compositor reports.
    final playPauseKeys = <LogicalKeyboardKey>{
      LogicalKeyboardKey.mediaPlayPause,
      LogicalKeyboardKey.mediaPlay,
      LogicalKeyboardKey.mediaPause,
    };
    final playPauseActivator =
        hotkeysSettings[HotkeysAction.mediaPlayPause.actionId];
    if (playPauseActivator != null &&
        playPauseActivator.keys.length == 1 &&
        playPauseKeys.contains(playPauseActivator.keys.single)) {
      final playPauseIntent = getActionIntent(HotkeysAction.mediaPlayPause);
      for (final key in playPauseKeys) {
        map[LogicalKeySet.fromSet({key})] = playPauseIntent;
      }
    }

    // add the dev tools shortcuts
    map[const SingleActivator(
          LogicalKeyboardKey.f12,
          control: true,
          shift: true,
        )] =
        const ToggleDevToolsIntent();
    return map;
  }
}
