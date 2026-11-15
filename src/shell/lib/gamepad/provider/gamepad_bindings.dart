import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/gamepad/model/gamepad_button.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';

part 'gamepad_bindings.g.dart';

/// The gamepad bindings and repeat pace from `gamepad` in the settings.
typedef GamepadSettings = ({
  List<(GamepadChord, Intent)> bindings,
  Duration repeatDelay,
  Duration repeatInterval,
});

/// The intent of a bindable action id.
///
/// Every keyboard action (`keyboard.hotkeys`) is bindable by the same id. The
/// gamepad adds the ones a keyboard reaches through keys the framework or a
/// local context already binds (`Escape`, `Super+Tab`, a lone `Super`).
Intent? gamepadActionIntent(String actionId) {
  for (final action in HotkeysAction.values) {
    if (action.actionId == actionId) {
      return getActionIntent(action);
    }
  }
  return switch (actionId) {
    'navigation.dismiss' => const DismissIntent(),
    'navigation.cycleForward' => const CycleIntent(forward: true),
    'navigation.cycleBackward' => const CycleIntent(forward: false),
    'overview.toggle' => const ToggleOverviewIntent(),
    _ => null,
  };
}

/// Parses `gamepad.bindings`: nested groups of action ids, each mapped to a
/// list of chords (`{"navigation": {"up": ["dpadUp", "leftStickUp"]}}`).
///
/// An unknown action or a malformed chord is skipped (and logged) rather than
/// failing the whole table.
List<(GamepadChord, Intent)> parseGamepadBindings(Object? json) {
  final bindings = <(GamepadChord, Intent)>[];
  void visit(String prefix, Object? node) {
    if (node is Map) {
      for (final MapEntry(:key, :value) in node.entries) {
        visit(prefix.isEmpty ? '$key' : '$prefix.$key', value);
      }
      return;
    }
    if (node is! List) {
      return;
    }
    final intent = gamepadActionIntent(prefix);
    if (intent == null) {
      platformLog.warning('gamepad: unknown action "$prefix"');
      return;
    }
    for (final text in node) {
      final chord = text is String ? GamepadChord.tryParse(text) : null;
      if (chord == null) {
        platformLog.warning('gamepad: invalid chord "$text" for "$prefix"');
        continue;
      }
      bindings.add((chord, intent));
    }
  }

  visit('', json);
  return bindings;
}

@Riverpod(keepAlive: true)
GamepadSettings gamepadSettings(Ref ref) {
  Duration milliseconds(String path, int fallback) {
    final value = ref.watch(jsonValueByPathProvider(path));
    return Duration(
      milliseconds: value is int && value >= 0 ? value : fallback,
    );
  }

  return (
    bindings: parseGamepadBindings(
      ref.watch(jsonValueByPathProvider('gamepad.bindings')),
    ),
    repeatDelay: milliseconds('gamepad.repeatDelayMs', 400),
    repeatInterval: milliseconds('gamepad.repeatIntervalMs', 120),
  );
}
