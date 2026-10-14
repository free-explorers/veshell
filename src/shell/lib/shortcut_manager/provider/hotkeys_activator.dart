import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/state/hotkeys_setting.dart';
import 'package:shell/shortcut_manager/model/media_intents.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/model/system_intents.dart';

part 'hotkeys_activator.g.dart';

/// A bindable shell action.
///
/// The [actionId] is the settings key (`keyboard.hotkeys.<actionId>`) and the
/// stable identifier of the action. Directional, activate and dismiss actions
/// resolve to Flutter's own intents, so a binding drives the framework focus
/// system; contexts that are still index-based override the same intent.
enum HotkeysAction {
  increaseVolume('system.increaseVolume'),
  decreaseVolume('system.decreaseVolume'),
  toggleMute('system.muteVolume'),
  increaseBrightness('system.increaseBrightness'),
  decreaseBrightness('system.decreaseBrightness'),
  toggleKeyboardLayout('system.toggleKeyboardLayout'),
  mediaPlayPause('media.playPause'),
  mediaNext('media.next'),
  mediaPrevious('media.previous'),
  mediaStop('media.stop'),
  navigateUp('navigation.up'),
  navigateDown('navigation.down'),
  navigateLeft('navigation.left'),
  navigateRight('navigation.right'),
  moveUp('navigation.moveUp'),
  moveDown('navigation.moveDown'),
  moveLeft('navigation.moveLeft'),
  moveRight('navigation.moveRight'),
  activate('navigation.activate'),
  close('navigation.close');

  const HotkeysAction(this.actionId);
  final String actionId;
}

Intent getActionIntent(HotkeysAction action) => switch (action) {
  HotkeysAction.increaseVolume => const IncreaseVolume(),
  HotkeysAction.decreaseVolume => const DecreaseVolume(),
  HotkeysAction.toggleMute => const ToggleMute(),
  HotkeysAction.increaseBrightness => const IncreaseBrightness(),
  HotkeysAction.decreaseBrightness => const DecreaseBrightness(),
  HotkeysAction.toggleKeyboardLayout => const ToggleKeyboardLayout(),
  HotkeysAction.mediaPlayPause => const MediaPlayPauseIntent(),
  HotkeysAction.mediaNext => const MediaNextIntent(),
  HotkeysAction.mediaPrevious => const MediaPreviousIntent(),
  HotkeysAction.mediaStop => const MediaStopIntent(),
  HotkeysAction.navigateUp => const NavigateIntent(NavigationDirection.up),
  HotkeysAction.navigateDown => const NavigateIntent(NavigationDirection.down),
  HotkeysAction.navigateLeft => const NavigateIntent(NavigationDirection.left),
  HotkeysAction.navigateRight => const NavigateIntent(
    NavigationDirection.right,
  ),
  HotkeysAction.moveUp => const MoveIntent(NavigationDirection.up),
  HotkeysAction.moveDown => const MoveIntent(NavigationDirection.down),
  HotkeysAction.moveLeft => const MoveIntent(NavigationDirection.left),
  HotkeysAction.moveRight => const MoveIntent(NavigationDirection.right),
  HotkeysAction.activate => const ActivateIntent(),
  HotkeysAction.close => const CloseIntent(),
};

@riverpod
class HotkeysActivator extends _$HotkeysActivator {
  @override
  Map<ShortcutActivator, Intent> build() {
    final hotkeysSettings = ref.watch(hotkeysSettingProvider);

    final map = <ShortcutActivator, Intent>{};

    // Every action may carry several bindings; each one points at the same
    // intent. `LogicalKeySet.fromSet({})` matches every key event, so empty
    // bindings are skipped.
    for (final action in HotkeysAction.values) {
      final intent = getActionIntent(action);
      final activators =
          hotkeysSettings[action.actionId] ?? const <LogicalKeySet>[];
      for (final activator in activators) {
        if (activator.keys.isEmpty) {
          continue;
        }
        map[activator] = intent;
      }
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
    final playPauseIntent = getActionIntent(HotkeysAction.mediaPlayPause);
    for (final activator
        in hotkeysSettings[HotkeysAction.mediaPlayPause.actionId] ??
            const <LogicalKeySet>[]) {
      if (activator.keys.length == 1 &&
          playPauseKeys.contains(activator.keys.single)) {
        for (final key in playPauseKeys) {
          map[LogicalKeySet.fromSet({key})] = playPauseIntent;
        }
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
