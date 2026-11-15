import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/gamepad/model/gamepad_button.dart';
import 'package:shell/gamepad/model/gamepad_chord_resolver.dart';
import 'package:shell/gamepad/provider/gamepad_bindings.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'gamepad_navigation.g.dart';

/// Drives the shell's navigation from the gamepad.
///
/// The compositor reports logical gamepad buttons; this resolves them against
/// `gamepad.bindings` and dispatches the intents exactly as a keyboard chord
/// would: from the primary focus upwards, so the focused context (screen,
/// workspace, overview, Helm, a dialog) decides what a direction means.
@Riverpod(keepAlive: true)
class GamepadNavigation extends _$GamepadNavigation {
  @override
  void build() {
    final settings = ref.watch(gamepadSettingsProvider);
    final resolver = GamepadChordResolver(
      bindings: settings.bindings,
      invoke: invokeGamepadIntent,
      repeatDelay: settings.repeatDelay,
      repeatInterval: settings.repeatInterval,
    );
    final subscription = ref.watch(platformManagerProvider).listen((event) {
      if (event case GamepadButtonEvent(:final message)) {
        final button = GamepadButton.tryParse(message.button);
        if (button != null) {
          resolver.handle(button, pressed: message.pressed);
        }
      }
    });
    ref.onDispose(() {
      unawaited(subscription.cancel());
      resolver.reset();
    });
  }
}

/// Invokes [intent] on the primary focus, like `ShortcutManager` does for a
/// key: the nearest enabled action for it, from the focused widget upwards.
void invokeGamepadIntent(Intent intent) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) {
    return;
  }
  final action = Actions.maybeFind<Intent>(context, intent: intent);
  if (action == null) {
    return;
  }
  Actions.of(context).invokeActionIfEnabled(action, intent, context);
}
