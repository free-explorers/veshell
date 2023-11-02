import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/desktop/desktop_ui.dart';
import 'package:zenith/ui/mobile/mobile_ui.dart';
import 'package:zenith/ui/mobile/state/power_menu_state.dart';
import 'package:zenith/util/state/key_tracker.dart';
import 'package:zenith/util/state/lock_screen_state.dart';
import 'package:zenith/util/state/root_overlay.dart';
import 'package:zenith/util/state/screen_state.dart';
import 'package:zenith/util/state/ui_mode_state.dart';

void main() {
  // debugRepaintRainbowEnabled = true;
  // debugPrintGestureArenaDiagnostics = true;
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

  final platformApi = container.read(platformApiProvider.notifier);

  SchedulerBinding.instance.addPostFrameCallback((_) {
    platformApi.startupComplete();
  });

  container.read(platformApiProvider.notifier).init();

  _registerLockScreenKeyboardHandler(container);
  _registerPowerButtonHandler(container);

  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: Builder(
        builder: (context) {
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              bool screenOn = ref.watch(screenStateNotifierProvider.select((v) => v.on));
              final screenStateNotifier = ref.read(screenStateNotifierProvider.notifier);

              return GestureDetector(
                onDoubleTap: !screenOn ? () => screenStateNotifier.turnOn() : null,
                child: AbsorbPointer(
                  absorbing: !screenOn,
                  child: child,
                ),
              );
            },
            child: Zenith(),
          );
        },
      ),
    ),
  );
}

const _notchHeight = 80.0; // physical pixels

class Zenith extends ConsumerWidget {
  final GlobalKey<OverlayState> overlayKey = GlobalKey();

  Zenith({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      home: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          Future.microtask(() => ref.read(screenStateNotifierProvider.notifier).setSize(constraints.biggest));

          return RotatedBox(
            quarterTurns: ref.watch(screenStateNotifierProvider.select((v) => v.rotation)),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                Future.microtask(() => ref.read(screenStateNotifierProvider.notifier).setRotatedSize(constraints.biggest));

                return ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    // Enable scrolling by dragging the mouse cursor.
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.invertedStylus,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.unknown,
                    },
                  ),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: EdgeInsets.only(
                        top: _notchHeight / MediaQuery.of(context).devicePixelRatio,
                      ),
                    ),
                    child: Scaffold(
                      body: Consumer(
                        builder: (BuildContext context, WidgetRef ref, Widget? child) {
                          UiMode uiMode = ref.watch(uiModeStateProvider);
                          return Stack(
                            children: [
                              if (uiMode == UiMode.desktop) const DesktopUi(),
                              if (uiMode == UiMode.mobile) const MobileUi(),
                              Overlay(
                                key: ref.watch(rootOverlayKeyProvider),
                                initialEntries: const [
                                  // ref.read(lockScreenStateProvider).overlayEntry, // Start with the session locked.
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

void _registerLockScreenKeyboardHandler(ProviderContainer container) {
  HardwareKeyboard.instance.addHandler((KeyEvent keyEvent) {
    if (container.read(lockScreenStateProvider).locked) {
      // We don't want to send keyboard events to Wayland clients when the screen
      // is locked. Capture all keyboard events.
      return true;
    }
    return false;
  });
}

void _registerPowerButtonHandler(ProviderContainer container) {
  const KeyboardKey powerKey = LogicalKeyboardKey.powerOff;

  HardwareKeyboard.instance.addHandler((KeyEvent keyEvent) {
    if (keyEvent.logicalKey == powerKey) {
      if (keyEvent is KeyDownEvent) {
        container.read(keyTrackerProvider(keyEvent.logicalKey).notifier).down();
      } else if (keyEvent is KeyUpEvent) {
        container.read(keyTrackerProvider(keyEvent.logicalKey).notifier).up();
      }
      return true;
    }
    return false;
  });

  bool turnedOn = false;

  container.listen(keyTrackerProvider(powerKey).select((v) => v.down), (_, __) {
    final screenState = container.read(screenStateNotifierProvider);
    final screenStateNotifier = container.read(screenStateNotifierProvider.notifier);
    if (!screenState.on) {
      turnedOn = true;
      screenStateNotifier.turnOn();
      container.read(powerMenuStateNotifierProvider.notifier).removeOverlay();
    } else {
      turnedOn = false;
    }
  });

  container.listen(keyTrackerProvider(powerKey).select((v) => v.shortPress), (_, __) {
    final screenState = container.read(screenStateNotifierProvider);
    final screenStateNotifier = container.read(screenStateNotifierProvider.notifier);
    if (screenState.on && !turnedOn) {
      screenStateNotifier.lockAndTurnOff();
      container.read(powerMenuStateNotifierProvider.notifier).removeOverlay();
    }
  });

  container.listen(keyTrackerProvider(powerKey).select((v) => v.longPress), (_, __) {
    final state = container.read(powerMenuStateNotifierProvider);
    final notifier = container.read(powerMenuStateNotifierProvider.notifier);

    if (!state.shown) {
      notifier.show();
    } else {
      notifier.hide();
    }
  });
}
