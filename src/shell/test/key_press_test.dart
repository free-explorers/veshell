import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/key_press/model/key_press_history.dart';
import 'package:shell/key_press/provider/key_press_recorder.dart';
import 'package:shell/key_press/widget/key_press_overlay.dart';
import 'package:shell/lock_screen/model/lock_screen_state/lock_screen_state.dart';
import 'package:shell/lock_screen/provider/lock_screen.dart';
import 'package:shell/settings/provider/state/show_key_presses_setting.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/status_bar/model/clock_format.dart';
import 'package:shell/status_bar/model/status_bar_style.dart';
import 'package:shell/status_bar/provider/status_bar_settings.dart';
import 'package:shell/status_bar/widget/status_top_panel.dart';
import 'package:shell/theme/provider/theme.dart';

const Duration _time = Duration.zero;

KeyDownEvent _down(LogicalKeyboardKey key, {String? character}) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  character: character,
  timeStamp: _time,
);

KeyRepeatEvent _repeat(LogicalKeyboardKey key, {String? character}) =>
    KeyRepeatEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      character: character,
      timeStamp: _time,
    );

KeyUpEvent _up(LogicalKeyboardKey key) => KeyUpEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  timeStamp: _time,
);

/// Replays presses and releases, tracking the held keys as
/// `HardwareKeyboard` would.
class _Keyboard {
  KeyPressHistory history = const KeyPressHistory();
  final _pressed = <LogicalKeyboardKey>{};

  void down(LogicalKeyboardKey key, [String? character]) {
    _pressed.add(key);
    history = history.record(_down(key, character: character), {..._pressed});
  }

  void repeat(LogicalKeyboardKey key, [String? character]) {
    history = history.record(_repeat(key, character: character), {..._pressed});
  }

  void up(LogicalKeyboardKey key) {
    _pressed.remove(key);
    history = history.record(_up(key), {..._pressed});
  }

  void tap(LogicalKeyboardKey key, [String? character]) {
    down(key, character);
    up(key);
  }

  void type(String text) {
    for (final character in text.split('')) {
      tap(LogicalKeyboardKey(character.codeUnitAt(0)), character);
    }
  }
}

/// The chord shown, as `Ctrl+Z x2`.
String? _describe(KeyPressHistory history) {
  final shown = history.shown;
  if (shown == null) return null;
  return shown.keys.join('+') + (shown.count > 1 ? ' x${shown.count}' : '');
}

class _Unlocked extends LockScreen {
  @override
  LockScreenState build() => const LockScreenState();
}

class _Locked extends LockScreen {
  @override
  LockScreenState build() => const LockScreenState(locked: true);
}

void main() {
  group('KeyPressHistory', () {
    test('a key with modifiers is one chord, modifiers first', () {
      final keyboard = _Keyboard()
        ..down(LogicalKeyboardKey.shiftLeft)
        ..down(LogicalKeyboardKey.controlRight)
        ..tap(LogicalKeyboardKey.keyT, 'T')
        ..up(LogicalKeyboardKey.controlRight)
        ..up(LogicalKeyboardKey.shiftLeft);
      expect(_describe(keyboard.history), 'Ctrl+Shift+T');
      expect(keyboard.history.visible, isTrue);
      expect(keyboard.history.pressed, isEmpty);
    });

    test('only the latest chord is shown', () {
      final keyboard = _Keyboard()
        ..type('hi')
        ..tap(LogicalKeyboardKey.enter, '\r')
        ..tap(LogicalKeyboardKey.arrowUp);
      expect(_describe(keyboard.history), '↑');
      keyboard.type('a');
      expect(_describe(keyboard.history), 'A');
    });

    test('the same chord again is counted', () {
      final keyboard = _Keyboard()..down(LogicalKeyboardKey.controlLeft);
      for (var i = 0; i < 3; i++) {
        keyboard.tap(LogicalKeyboardKey.keyZ, 'z');
      }
      keyboard.up(LogicalKeyboardKey.controlLeft);
      expect(_describe(keyboard.history), 'Ctrl+Z x3');
      keyboard
        ..down(LogicalKeyboardKey.controlLeft)
        ..tap(LogicalKeyboardKey.keyZ, 'z')
        ..up(LogicalKeyboardKey.controlLeft);
      expect(_describe(keyboard.history), 'Ctrl+Z x4');
      keyboard.type('ll');
      expect(_describe(keyboard.history), 'L x2');
    });

    test('a held key counts its repeats', () {
      final keyboard = _Keyboard()
        ..down(LogicalKeyboardKey.backspace)
        ..repeat(LogicalKeyboardKey.backspace)
        ..repeat(LogicalKeyboardKey.backspace)
        ..up(LogicalKeyboardKey.backspace);
      expect(_describe(keyboard.history), 'Backspace x3');
    });

    test('modifiers held wait for their key', () {
      final keyboard = _Keyboard()
        ..tap(LogicalKeyboardKey.f1)
        ..down(LogicalKeyboardKey.controlLeft)
        ..down(LogicalKeyboardKey.shiftRight);
      expect(_describe(keyboard.history), 'Ctrl+Shift');
      keyboard.down(LogicalKeyboardKey.keyT, 'T');
      expect(_describe(keyboard.history), 'Ctrl+Shift+T');
    });

    test('modifiers pressed and released alone are a chord', () {
      final keyboard = _Keyboard()
        ..down(LogicalKeyboardKey.superKey)
        ..up(LogicalKeyboardKey.superKey);
      expect(_describe(keyboard.history), 'Super');
      keyboard
        ..down(LogicalKeyboardKey.controlLeft)
        ..down(LogicalKeyboardKey.altLeft)
        ..up(LogicalKeyboardKey.controlLeft)
        ..up(LogicalKeyboardKey.altLeft);
      expect(_describe(keyboard.history), 'Ctrl+Alt');
    });

    test('modifiers of a chord are not shown alone on release', () {
      final keyboard = _Keyboard()
        ..down(LogicalKeyboardKey.metaLeft)
        ..tap(LogicalKeyboardKey.keyK, 'k')
        ..down(LogicalKeyboardKey.shiftLeft)
        ..up(LogicalKeyboardKey.shiftLeft)
        ..up(LogicalKeyboardKey.metaLeft);
      expect(_describe(keyboard.history), 'Super+K');
    });

    test('the keys held right now are known by label', () {
      final keyboard = _Keyboard()
        ..down(LogicalKeyboardKey.controlLeft)
        ..down(LogicalKeyboardKey.keyC, 'c');
      expect(keyboard.history.pressed, {'Ctrl', 'C'});
      keyboard.up(LogicalKeyboardKey.keyC);
      expect(keyboard.history.pressed, {'Ctrl'});
      expect(_describe(keyboard.history), 'Ctrl+C');
    });

    test('a press after it was hidden starts afresh', () {
      final keyboard = _Keyboard()..type('aa');
      keyboard.history = keyboard.history.hidden();
      expect(_describe(keyboard.history), 'A x2');
      expect(keyboard.history.visible, isFalse);
      keyboard.type('a');
      expect(_describe(keyboard.history), 'A');
      expect(keyboard.history.visible, isTrue);
    });
  });

  group('KeyPressOverlay', () {
    Future<List<KeyEvent>> pumpOverlay(
      WidgetTester tester, {
      bool enabled = true,
      KeyPressPosition position = KeyPressPosition.bottomRight,
      StatusBarStyle statusBar = StatusBarStyle.none,
      LockScreen Function() lockScreen = _Unlocked.new,
    }) async {
      final received = <KeyEvent>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showKeyPressesSettingProvider.overrideWithValue(enabled),
            keyPressPositionSettingProvider.overrideWithValue(position),
            statusBarSettingsProvider.overrideWithValue((
              style: statusBar,
              showClock: true,
              clockFormat: ClockFormat.locale,
              showKeyboardLayout: true,
              showSystemTray: true,
              showWifi: true,
              showVolume: true,
              showBattery: true,
              showBatteryPercentage: true,
            )),
            lockScreenProvider.overrideWith(lockScreen),
          ],
          child: MaterialApp(
            home: Stack(
              children: [
                // The focused widget: the overlay only watches, so the keys
                // still reach it.
                Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    received.add(event);
                    return KeyEventResult.ignored;
                  },
                  child: const SizedBox.expand(),
                ),
                const KeyPressOverlay(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return received;
    }

    testWidgets('shows a chord pressed anywhere, then fades out', (
      tester,
    ) async {
      await pumpOverlay(tester);
      bool lit(String label) =>
          tester.widget<Keycap>(find.widgetWithText(Keycap, label)).pressed;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(lit('Ctrl'), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.pump();
      expect(lit('Ctrl'), isTrue);
      expect(lit('K'), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.pump();
      expect(lit('Ctrl'), isTrue);
      expect(lit('K'), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(lit('Ctrl'), isFalse);
      expect(find.text('×2'), findsOneWidget);

      double opacity() =>
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
      expect(opacity(), 1);
      await tester.pump(keyPressLinger);
      expect(opacity(), 0);
      await tester.pumpAndSettle();
    });

    testWidgets('the keys still reach the focused widget', (tester) async {
      final received = await pumpOverlay(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ, character: 'q');
      await tester.pump();
      expect(received.whereType<KeyDownEvent>().map((e) => e.logicalKey), [
        LogicalKeyboardKey.keyQ,
      ]);
      expect(find.text('Q'), findsOneWidget);
      await tester.pumpAndSettle(keyPressLinger);
    });

    testWidgets('shows nothing while turned off', (tester) async {
      await pumpOverlay(tester, enabled: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(find.byType(KeyPressPanel), findsNothing);
      expect(find.text('F5'), findsNothing);
    });

    testWidgets('sits where configured, clear of the shell panels', (
      tester,
    ) async {
      Future<Rect> panelAt(
        KeyPressPosition position, {
        StatusBarStyle statusBar = StatusBarStyle.none,
      }) async {
        await pumpOverlay(tester, position: position, statusBar: statusBar);
        await tester.sendKeyEvent(LogicalKeyboardKey.f5);
        await tester.pump();
        final rect = tester.getRect(find.byType(KeyPressPanel));
        await tester.pumpAndSettle(keyPressLinger);
        return rect;
      }

      const gap = KeyPressOverlay.gap;
      final bottomRight = await panelAt(KeyPressPosition.bottomRight);
      final screen = tester.getRect(find.byType(KeyPressOverlay));
      expect(bottomRight.right, screen.right - gap);
      expect(bottomRight.bottom, screen.bottom - KeyPressOverlay.bottomMargin);

      // Clear of the screen panel on the left and the workspace panel on top.
      final topLeft = await panelAt(KeyPressPosition.topLeft);
      expect(topLeft.topLeft, const Offset(panelSize + gap, panelSize + gap));

      // The status bar's top panel pushes it further down.
      final belowStatusBar = await panelAt(
        KeyPressPosition.topCenter,
        statusBar: StatusBarStyle.topPanel,
      );
      expect(belowStatusBar.top, panelSize + StatusTopPanel.height + gap);
    });

    testWidgets('records nothing while the session is locked', (tester) async {
      await pumpOverlay(tester, lockScreen: _Locked.new);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP, character: 'p');
      await tester.pump();
      expect(find.byType(KeyPressPanel), findsNothing);
    });
  });

  group('keyPressPositionSetting', () {
    KeyPressPosition read(Object? stored) {
      final container = ProviderContainer(
        overrides: [
          jsonValueByPathProvider(
            keyPressPositionPath,
          ).overrideWithValue(stored),
        ],
      );
      addTearDown(container.dispose);
      return container.read(keyPressPositionSettingProvider);
    }

    test('reads a stored position', () {
      expect(read('topCenter'), KeyPressPosition.topCenter);
    });

    test('falls back to the bottom right', () {
      expect(read(null), KeyPressPosition.bottomRight);
      expect(read('middle'), KeyPressPosition.bottomRight);
    });
  });
}
