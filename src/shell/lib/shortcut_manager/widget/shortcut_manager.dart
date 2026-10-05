import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/platform/model/request/adjust_brightness/adjust_brightness.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/mpris/provider/mpris_manager.dart';
import 'package:shell/shared/pulseaudio/provider/default_sink.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_sink_by_name.dart';
import 'package:shell/shortcut_manager/model/media_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/model/system_intents.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';

class VeshellShortcutManager extends HookConsumerWidget {
  const VeshellShortcutManager({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotkeysActivator = ref.watch(hotkeysActivatorProvider);
    print(hotkeysActivator);
    final manager = useMemoized(
      () => _ShortcutManager(shortcuts: hotkeysActivator),
      [hotkeysActivator],
    );
    // A chord consumed by a local `Shortcuts` widget (for example Super+W in
    // the overview) never reaches the shortcut manager, which would then still
    // toggle the overview when Super is released. Track the Super-sole-press
    // state from the global hardware keyboard instead.
    useEffect(() {
      bool handleHardwareKey(KeyEvent event) {
        manager.trackHardwareKey(event);
        return false;
      }

      HardwareKeyboard.instance.addHandler(handleHardwareKey);
      return () => HardwareKeyboard.instance.removeHandler(handleHardwareKey);
    }, [manager]);
    return Shortcuts.manager(
      manager: manager,
      child: Actions(
        actions: {
          IncreaseVolume: CallbackAction<IncreaseVolume>(
            onInvoke: (IncreaseVolume intent) {
              final defaultSink = ref.read(defaultPulseSinkProvider);
              if (defaultSink == null) return;
              final sink = ref.read(pulseSinkByNameProvider(defaultSink.name));
              if (sink == null) return;

              ref
                  .read(pulseClientProvider)
                  .requireValue
                  .setSinkVolume(defaultSink.name, min(sink.volume + 0.05, 1));
              return null;
            },
          ),
          DecreaseVolume: CallbackAction<DecreaseVolume>(
            onInvoke: (DecreaseVolume intent) {
              final defaultSink = ref.read(defaultPulseSinkProvider);
              if (defaultSink == null) return;
              final sink = ref.read(pulseSinkByNameProvider(defaultSink.name));
              if (sink == null) return;
              ref
                  .read(pulseClientProvider)
                  .requireValue
                  .setSinkVolume(defaultSink.name, max(sink.volume - 0.05, 0));

              return null;
            },
          ),
          ToggleMute: CallbackAction<ToggleMute>(
            onInvoke: (ToggleMute intent) {
              final defaultSink = ref.read(defaultPulseSinkProvider);
              if (defaultSink == null) return;
              final sink = ref.read(pulseSinkByNameProvider(defaultSink.name));
              if (sink == null) return;
              ref
                  .read(pulseClientProvider)
                  .requireValue
                  .setSinkMute(defaultSink.name, !sink.mute);
              return;
            },
          ),
          // Brightness is owned by the compositor (logind/sysfs); the shell
          // only forwards the requested step. The compositor clamps it and
          // restores the user level after an idle dim.
          IncreaseBrightness: CallbackAction<IncreaseBrightness>(
            onInvoke: (_) {
              ref
                  .read(platformManagerProvider.notifier)
                  .request(
                    AdjustBrightnessRequest(
                      message: AdjustBrightnessMessage(delta: 0.05),
                    ),
                  );
              return null;
            },
          ),
          DecreaseBrightness: CallbackAction<DecreaseBrightness>(
            onInvoke: (_) {
              ref
                  .read(platformManagerProvider.notifier)
                  .request(
                    AdjustBrightnessRequest(
                      message: AdjustBrightnessMessage(delta: -0.05),
                    ),
                  );
              return null;
            },
          ),
          // Hardware media keys drive the active MPRIS player. The compositor
          // sends every key to Flutter first, so handling them here keeps them
          // global: a handled shortcut is never forwarded to the focused
          // client.
          MediaPlayPauseIntent: CallbackAction<MediaPlayPauseIntent>(
            onInvoke: (_) {
              ref.read(mprisManagerProvider.notifier).playPause();
              return null;
            },
          ),
          MediaNextIntent: CallbackAction<MediaNextIntent>(
            onInvoke: (_) {
              ref.read(mprisManagerProvider.notifier).next();
              return null;
            },
          ),
          MediaPreviousIntent: CallbackAction<MediaPreviousIntent>(
            onInvoke: (_) {
              ref.read(mprisManagerProvider.notifier).previous();
              return null;
            },
          ),
          MediaStopIntent: CallbackAction<MediaStopIntent>(
            onInvoke: (_) {
              ref.read(mprisManagerProvider.notifier).stop();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _ShortcutManager extends ShortcutManager {
  _ShortcutManager({super.shortcuts});
  bool _isOverviewKeySolePressed = false;
  ToggleOverviewIntent overviewIntent = const ToggleOverviewIntent();
  final LogicalKeyboardKey overviewKey = LogicalKeyboardKey.superKey;

  /// Mirrors the Super-sole-press state from the global hardware keyboard.
  ///
  /// [handleKeypress] only sees events that no local `Shortcuts` consumed, so a
  /// chord like Super+W handled inside the overview would otherwise leave this
  /// flag set and toggle the overview when Super is released.
  void trackHardwareKey(KeyEvent event) {
    if (event.synthesized) {
      return;
    }
    if (event is KeyDownEvent && event.logicalKey == overviewKey) {
      _isOverviewKeySolePressed = true;
    } else if (event.logicalKey != overviewKey &&
        (event is KeyDownEvent || event is KeyRepeatEvent)) {
      _isOverviewKeySolePressed = false;
    }
  }

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (event is KeyUpEvent && event.logicalKey == overviewKey) {
      final wasSolePressed = _isOverviewKeySolePressed;
      _isOverviewKeySolePressed = false;
      // A synthesized release (focus change, etc.) must not toggle.
      if (event.synthesized) {
        return KeyEventResult.handled;
      }
      if (wasSolePressed) {
        final primaryContext = primaryFocus?.context;
        if (primaryContext != null) {
          final action = Actions.maybeFind<Intent>(
            primaryContext,
            intent: overviewIntent,
          );
          if (action != null) {
            final (bool enabled, Object? invokeResult) = Actions.of(
              primaryContext,
            ).invokeActionIfEnabled(action, overviewIntent, primaryContext);
            if (enabled) {
              return action.toKeyEventResult(overviewIntent, invokeResult);
            }
          }
        }
      }
    }

    return super.handleKeypress(context, event);
  }
}
