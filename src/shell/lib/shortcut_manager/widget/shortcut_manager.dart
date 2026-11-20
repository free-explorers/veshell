import 'dart:async';
import 'dart:math';
import 'dart:ui' show ViewFocusDirection, ViewFocusState;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/lock_screen/provider/lock_screen.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/monitor/provider/platform_focused_view.dart';
import 'package:shell/notification/provider/system_notification_manager.dart';
import 'package:shell/platform/model/request/adjust_brightness/adjust_brightness.serializable.dart';
import 'package:shell/platform/model/request/switch_keyboard_layout/switch_keyboard_layout.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/monitor_for_screen.dart';
import 'package:shell/screen/provider/pointer_screen.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/state/show_key_presses_setting.dart';
import 'package:shell/shared/mpris/provider/mpris_manager.dart';
import 'package:shell/shared/pulseaudio/provider/default_sink.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_sink_by_name.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shortcut_manager/model/media_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/model/super_key.dart';
import 'package:shell/shortcut_manager/model/system_intents.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/tile_grab/provider/tile_grab_controller.dart';

class VeshellShortcutManager extends HookConsumerWidget {
  const VeshellShortcutManager({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotkeysActivator = ref.watch(hotkeysActivatorProvider);
    final manager = useMemoized(
      () => _ShortcutManager(
        shortcuts: hotkeysActivator,
        // While a tile is held, its controller acts on the screen under the
        // pointer, which is not the one holding keyboard focus.
        interceptIntent: (intent) =>
            ref.read(tileGrabControllerProvider.notifier).handleIntent(intent),
        // The keyboard follows clicks, but the shell's hotkeys act on the
        // screen under the pointer.
        pointerScreenElsewhere: () {
          // Nothing to follow until the pointer entered a screen.
          if (ref.read(pointerScreenProvider) == null) {
            return null;
          }
          final pointerScreen = ref.read(placementScreenProvider);
          return pointerScreen != ref.read(focusedScreenProvider)
              ? pointerScreen
              : null;
        },
        focusScreen: (screenId) {
          // As a click would: the compositor moves the keyboard to the
          // screen's monitor, and the screen is the one chosen on it.
          final monitorName = ref.read(monitorForScreenProvider(screenId));
          final viewId = monitorName == null
              ? null
              : ref.read(monitorByNameProvider(monitorName))?.viewId;
          if (viewId != null &&
              viewId != ref.read(platformFocusedViewIdProvider)) {
            WidgetsBinding.instance.platformDispatcher.requestViewFocusChange(
              viewId: viewId,
              state: ViewFocusState.focused,
              direction: ViewFocusDirection.undefined,
            );
          }
          ref.read(focusedScreenProvider.notifier).setFocusedScreen(screenId);
        },
      ),
      [hotkeysActivator],
    );
    // A pointer press while Super is held (a tile grab, any Super + click) is
    // a chord, not a sole press: its release must not toggle the overview.
    // Watching the pointer itself, rather than what the press started, holds
    // whatever the press ends up doing.
    useEffect(() {
      void handlePointer(PointerEvent event) {
        if (event is PointerDownEvent && isSuperKeyPressed()) {
          manager.claimSuperPress();
        }
      }

      GestureBinding.instance.pointerRouter.addGlobalRoute(handlePointer);
      return () => GestureBinding.instance.pointerRouter.removeGlobalRoute(
        handlePointer,
      );
    }, [manager]);
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

              final volume = min(sink.volume + 0.05, 1.0);
              ref
                  .read(pulseClientProvider)
                  .requireValue
                  .setSinkVolume(defaultSink.name, volume);
              ref
                  .read(systemNotificationManagerProvider.notifier)
                  .showVolume(volume: volume, muted: sink.mute);
              return null;
            },
          ),
          DecreaseVolume: CallbackAction<DecreaseVolume>(
            onInvoke: (DecreaseVolume intent) {
              final defaultSink = ref.read(defaultPulseSinkProvider);
              if (defaultSink == null) return;
              final sink = ref.read(pulseSinkByNameProvider(defaultSink.name));
              if (sink == null) return;
              final volume = max(sink.volume - 0.05, 0.0);
              ref
                  .read(pulseClientProvider)
                  .requireValue
                  .setSinkVolume(defaultSink.name, volume);
              ref
                  .read(systemNotificationManagerProvider.notifier)
                  .showVolume(volume: volume, muted: sink.mute);

              return null;
            },
          ),
          ToggleMute: CallbackAction<ToggleMute>(
            onInvoke: (ToggleMute intent) {
              final defaultSink = ref.read(defaultPulseSinkProvider);
              if (defaultSink == null) return;
              final sink = ref.read(pulseSinkByNameProvider(defaultSink.name));
              if (sink == null) return;
              final muted = !sink.mute;
              ref
                  .read(pulseClientProvider)
                  .requireValue
                  .setSinkMute(defaultSink.name, muted);
              ref
                  .read(systemNotificationManagerProvider.notifier)
                  .showVolume(volume: sink.volume, muted: muted);
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
          // The compositor owns the seat's xkb state; the shell only asks it to
          // advance to the next layout compiled from `keyboard.layout`.
          ToggleKeyboardLayout: CallbackAction<ToggleKeyboardLayout>(
            onInvoke: (_) {
              ref
                  .read(platformManagerProvider.notifier)
                  .request(const SwitchKeyboardLayoutRequest());
              return null;
            },
          ),
          LockSessionIntent: CallbackAction<LockSessionIntent>(
            onInvoke: (_) {
              ref.read(lockScreenProvider.notifier).lock();
              return null;
            },
          ),
          ToggleKeyPressesIntent: CallbackAction<ToggleKeyPressesIntent>(
            onInvoke: (_) {
              ref
                  .read(settingsPropertiesProvider.notifier)
                  .updateProperty(
                    showKeyPressesPath,
                    !ref.read(showKeyPressesSettingProvider),
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
  _ShortcutManager({
    super.shortcuts,
    this.interceptIntent,
    this.pointerScreenElsewhere,
    this.focusScreen,
  });
  bool _isOverviewKeySolePressed = false;
  ToggleOverviewIntent overviewIntent = const ToggleOverviewIntent();
  final LogicalKeyboardKey overviewKey = LogicalKeyboardKey.superKey;

  /// Gets the first look at every bound intent; returning `true` consumes the
  /// key without dispatching the intent to the focused context.
  final bool Function(Intent intent)? interceptIntent;

  /// The screen under the pointer when it is not the screen holding the
  /// keyboard, or `null`.
  final ScreenId? Function()? pointerScreenElsewhere;

  /// Hands the keyboard to a screen, as a click on it would.
  final void Function(ScreenId screenId)? focusScreen;

  /// Intents that act on the whole system, wherever the pointer is: they
  /// never move the keyboard to another screen.
  static const _globalIntentTypes = <Type>{
    IncreaseVolume,
    DecreaseVolume,
    ToggleMute,
    IncreaseBrightness,
    DecreaseBrightness,
    ToggleKeyboardLayout,
    LockSessionIntent,
    ToggleKeyPressesIntent,
    MediaPlayPauseIntent,
    MediaNextIntent,
    MediaPreviousIntent,
    MediaStopIntent,
  };

  /// Sends a Super hotkey to the screen under the pointer when the keyboard
  /// is on another screen: that screen takes the keyboard first (the hotkey
  /// says the user is working there), then [intent] is invoked in its focused
  /// context once the keyboard has reached it.
  ///
  /// Returns whether [intent] was sent there; when it was not, it acts on the
  /// screen holding the keyboard as usual.
  bool _sendToPointerScreen(Intent intent) {
    if (_globalIntentTypes.contains(intent.runtimeType)) {
      return false;
    }
    final screenId = pointerScreenElsewhere?.call();
    final focusScreen = this.focusScreen;
    if (screenId == null || focusScreen == null) {
      return false;
    }
    focusScreen(screenId);
    unawaited(_invokeOnceFocused(screenId, intent));
    return true;
  }

  /// Invokes [intent] in the primary focus context as soon as it lies in
  /// [screenId]: the screen's workspace gate opens and its selected tile takes
  /// the keyboard over the next frames.
  static Future<void> _invokeOnceFocused(
    ScreenId screenId,
    Intent intent,
  ) async {
    for (var frame = 0; frame < 5; frame++) {
      await WidgetsBinding.instance.endOfFrame;
      final context = primaryFocus?.context;
      if (context != null &&
          context.mounted &&
          CurrentScreenId.maybeOf(context) == screenId) {
        Actions.maybeInvoke(context, intent);
        return;
      }
    }
    focusLog.warning(
      'Dropped $intent: the keyboard did not reach screen $screenId',
    );
  }

  /// Whether the held Super key was used by a pointer press.
  bool _isSuperClaimed = false;

  /// Whether a Super press was seen without its release yet.
  bool _isSuperDown = false;

  /// Marks the held Super key as used by a pointer press: its release
  /// neither toggles the overview nor reaches the client as a lone Super tap.
  void claimSuperPress() {
    _isOverviewKeySolePressed = false;
    _isSuperClaimed = isSuperKeyPressed();
  }

  /// Mirrors the Super-sole-press state from the global hardware keyboard.
  ///
  /// [handleKeypress] only sees events that no local `Shortcuts` consumed, so a
  /// chord like Super+W handled inside the overview would otherwise leave this
  /// flag set and toggle the overview when Super is released.
  void trackHardwareKey(KeyEvent event) {
    // Any release ends the press, a synthesized one (focus change) included.
    if (event is KeyUpEvent && event.logicalKey == overviewKey) {
      _isSuperDown = false;
      return;
    }
    if (event.synthesized) {
      return;
    }
    if (event.logicalKey == overviewKey) {
      if (event is KeyDownEvent && !_isSuperDown) {
        // Only a fresh press starts a sole press: a duplicate press of the
        // held key (which release builds let through) must keep the chord a
        // pointer press or another key already made of it.
        _isSuperDown = true;
        _isOverviewKeySolePressed = true;
        _isSuperClaimed = false;
      }
    } else if (event is KeyDownEvent || event is KeyRepeatEvent) {
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
      if (_isSuperClaimed) {
        _isSuperClaimed = false;
        return KeyEventResult.handled;
      }
      if (wasSolePressed && interceptIntent?.call(overviewIntent) == true) {
        return KeyEventResult.handled;
      }
      if (wasSolePressed && _sendToPointerScreen(overviewIntent)) {
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

    final intercept = interceptIntent;
    if (intercept != null &&
        (event is KeyDownEvent || event is KeyRepeatEvent)) {
      for (final MapEntry(key: activator, value: intent) in shortcuts.entries) {
        if (activator.accepts(event, HardwareKeyboard.instance) &&
            intercept(intent)) {
          return KeyEventResult.handled;
        }
      }
    }

    // A Super chord bound to a screen action acts on the screen under the
    // pointer. Plain-key bindings (Enter for `navigation.activate`) belong to
    // the focused widget and never move.
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        isSuperKeyPressed()) {
      for (final MapEntry(key: activator, value: intent) in shortcuts.entries) {
        if (activator.accepts(event, HardwareKeyboard.instance)) {
          if (_sendToPointerScreen(intent)) {
            return KeyEventResult.handled;
          }
          break;
        }
      }
    }

    return super.handleKeypress(context, event);
  }
}
