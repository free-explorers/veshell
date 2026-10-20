import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/shortcut_manager/widget/shortcut_manager.dart';
import 'package:shell/wayland/widget/surface/surface_focus.dart';

/// Regression tests for shell chords over a focused client surface.
///
/// Two things used to shadow the shell's chords before the global manager could
/// resolve them:
///
///  * `MaterialApp` installs `DefaultTextEditingShortcuts` and the default
///    `WidgetsApp` shortcuts, whose plain-key `SingleActivator`s (arrow keys,
///    Space, …) ignore the Super key and therefore also match a `Super+Arrow`
///    chord. When the manager sat *above* the `MaterialApp`, a focused text
///    field (the launcher search autofocuses) consumed the arrow first.
///    `MonitorWidget` now places `VeshellShortcutManager` inside the
///    `MaterialApp`, below those shortcuts and closer to focus.
///  * `SurfaceFocus` used a fixed pass-through list. It now checks the
///    configured shell hotkeys and leaves every claimed chord to the shell,
///    while plain client keys (Enter, Space, Escape, arrows, …) and unclaimed
///    chords are forwarded to the client.
///
/// The runtime engine reports Super as `LogicalKeyboardKey.superKey`; the test
/// harness cannot synthesize that key through `sendKeyDownEvent` (it asserts
/// on the physical-key lookup), so the events are injected as `ui.KeyData`
/// with `synthesized: true`, which dispatches them immediately.
void main() {
  void sendKey(
    LogicalKeyboardKey logical,
    PhysicalKeyboardKey physical, {
    required bool down,
  }) {
    ServicesBinding.instance.keyEventManager.handleKeyData(
      ui.KeyData(
        type: down ? ui.KeyEventType.down : ui.KeyEventType.up,
        physical: physical.usbHidUsage,
        logical: logical.keyId,
        timeStamp: Duration.zero,
        character: null,
        synthesized: true,
      ),
    );
  }

  Future<void> pressSuperArrowDown(WidgetTester tester) async {
    sendKey(
      LogicalKeyboardKey.superKey,
      PhysicalKeyboardKey.superKey,
      down: true,
    );
    sendKey(
      LogicalKeyboardKey.arrowDown,
      PhysicalKeyboardKey.arrowDown,
      down: true,
    );
    sendKey(
      LogicalKeyboardKey.arrowDown,
      PhysicalKeyboardKey.arrowDown,
      down: false,
    );
    sendKey(
      LogicalKeyboardKey.superKey,
      PhysicalKeyboardKey.superKey,
      down: false,
    );
    await tester.pump();
  }

  Future<void> pressCtrlSuperArrowDown(WidgetTester tester) async {
    sendKey(
      LogicalKeyboardKey.controlLeft,
      PhysicalKeyboardKey.controlLeft,
      down: true,
    );
    sendKey(
      LogicalKeyboardKey.superKey,
      PhysicalKeyboardKey.superKey,
      down: true,
    );
    sendKey(
      LogicalKeyboardKey.arrowDown,
      PhysicalKeyboardKey.arrowDown,
      down: true,
    );
    sendKey(
      LogicalKeyboardKey.arrowDown,
      PhysicalKeyboardKey.arrowDown,
      down: false,
    );
    sendKey(
      LogicalKeyboardKey.superKey,
      PhysicalKeyboardKey.superKey,
      down: false,
    );
    sendKey(
      LogicalKeyboardKey.controlLeft,
      PhysicalKeyboardKey.controlLeft,
      down: false,
    );
    await tester.pump();
  }

  final navigation = <ShortcutActivator, Intent>{
    LogicalKeySet.fromSet({
      LogicalKeyboardKey.superKey,
      LogicalKeyboardKey.arrowDown,
    }): const NavigateIntent(
      NavigationDirection.down,
    ),
    LogicalKeySet.fromSet({
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.superKey,
      LogicalKeyboardKey.arrowDown,
    }): const NavigateIntent(
      NavigationDirection.down,
    ),
    LogicalKeySet.fromSet({
      LogicalKeyboardKey.superKey,
      LogicalKeyboardKey.keyS,
    }): const NavigateIntent(
      NavigationDirection.down,
    ),
  };

  /// Pumps the same ordering `MonitorWidget` uses: the shortcut manager lives
  /// inside the `MaterialApp` (via its `builder`), so it is closer to focus
  /// than the framework's default shortcuts.
  Future<List<NavigationDirection>> pumpMonitor(
    WidgetTester tester, {
    required Widget body,
    Map<ShortcutActivator, Intent>? activators,
  }) async {
    final forwarded = <NavigationDirection>[];
    final container = ProviderContainer(
      overrides: [
        hotkeysActivatorProvider.overrideWithValue(activators ?? navigation),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) =>
              VeshellShortcutManager(child: child ?? const SizedBox.shrink()),
          home: Actions(
            actions: {
              NavigateIntent: CallbackAction<NavigateIntent>(
                onInvoke: (intent) {
                  forwarded.add(intent.direction);
                  return null;
                },
              ),
            },
            child: Scaffold(body: body),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return forwarded;
  }

  /// Pumps a focused client surface and returns the intents the shell saw.
  Future<List<NavigationDirection>> pumpClientSurface(
    WidgetTester tester, {
    Map<ShortcutActivator, Intent>? activators,
  }) async {
    final surfaceFocus = FocusNode(debugLabel: 'test-surface');
    addTearDown(surfaceFocus.dispose);
    final forwarded = await pumpMonitor(
      tester,
      activators: activators,
      body: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: SurfaceFocus(focusNode: surfaceFocus, child: const SizedBox()),
        ),
      ),
    );
    surfaceFocus.requestFocus();
    await tester.pump();
    return forwarded;
  }

  testWidgets('Super+Arrow reaches the shell with a text field focused', (
    tester,
  ) async {
    // A focused text field is the case that regressed: it used to consume the
    // arrow through `DefaultTextEditingShortcuts` before the shell saw it.
    final forwarded = await pumpMonitor(
      tester,
      body: const Center(child: TextField(autofocus: true)),
    );

    await pressSuperArrowDown(tester);

    expect(forwarded, [NavigationDirection.down]);
  });

  testWidgets('Super+Arrow reaches the shell with a client surface focused', (
    tester,
  ) async {
    final forwarded = await pumpClientSurface(tester);

    await pressSuperArrowDown(tester);

    expect(forwarded, [NavigationDirection.down]);
  });

  testWidgets(
    'Ctrl+Super+Arrow reaches the shell with a client surface focused',
    (tester) async {
      final forwarded = await pumpClientSurface(tester);

      await pressCtrlSuperArrowDown(tester);

      expect(forwarded, [NavigationDirection.down]);
    },
  );

  testWidgets('an unconfigured Ctrl+Arrow is forwarded to the client', (
    tester,
  ) async {
    final forwarded = await pumpClientSurface(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(forwarded, isEmpty);
    expect(handled, isFalse);
  });

  testWidgets('a configured Ctrl+Arrow reaches the shell', (tester) async {
    // The pass-throughs are not a fixed list: once the user binds Ctrl+Arrow,
    // it belongs to the shell instead of being forwarded to the client.
    final forwarded = await pumpClientSurface(
      tester,
      activators: {
        LogicalKeySet.fromSet({
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.arrowDown,
        }): const NavigateIntent(
          NavigationDirection.down,
        ),
      },
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(forwarded, [NavigationDirection.down]);
    expect(handled, isTrue);
  });

  testWidgets('a local Super chord still reaches the shell', (tester) async {
    // The overview binds Super+Shift+Tab locally rather than through the
    // hotkey settings, so Super chords must stay with the shell.
    final forwarded = await pumpClientSurface(
      tester,
      activators: {
        LogicalKeySet.fromSet({
          LogicalKeyboardKey.superKey,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.tab,
        }): const NavigateIntent(
          NavigationDirection.down,
        ),
      },
    );

    sendKey(
      LogicalKeyboardKey.superKey,
      PhysicalKeyboardKey.superKey,
      down: true,
    );
    sendKey(
      LogicalKeyboardKey.shiftLeft,
      PhysicalKeyboardKey.shiftLeft,
      down: true,
    );
    sendKey(LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab, down: true);
    sendKey(LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab, down: false);
    sendKey(
      LogicalKeyboardKey.shiftLeft,
      PhysicalKeyboardKey.shiftLeft,
      down: false,
    );
    sendKey(
      LogicalKeyboardKey.superKey,
      PhysicalKeyboardKey.superKey,
      down: false,
    );
    await tester.pump();

    expect(forwarded, [NavigationDirection.down]);
  });

  testWidgets('Enter stays with the client even when it is configured', (
    tester,
  ) async {
    // `navigation.activate` binds Enter by default, but a focused client still
    // needs it (and Space, Escape, and the navigation keys).
    final forwarded = await pumpClientSurface(
      tester,
      activators: {
        LogicalKeySet.fromSet({LogicalKeyboardKey.enter}): const NavigateIntent(
          NavigationDirection.down,
        ),
      },
    );

    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(forwarded, isEmpty);
    expect(handled, isFalse);
  });

  testWidgets('a client surface still forwards plain arrows to the client', (
    tester,
  ) async {
    await pumpClientSurface(tester);

    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

    expect(handled, isFalse);
  });

  testWidgets('the shell chord still wins over the framework default', (
    tester,
  ) async {
    // `Super+S` guards that the ordering fix is not specific to the arrow
    // keys: every shell chord must beat the framework defaults.
    final forwarded = await pumpMonitor(
      tester,
      body: const Center(child: TextField(autofocus: true)),
    );

    sendKey(
      LogicalKeyboardKey.superKey,
      PhysicalKeyboardKey.superKey,
      down: true,
    );
    sendKey(LogicalKeyboardKey.keyS, PhysicalKeyboardKey.keyS, down: true);
    sendKey(LogicalKeyboardKey.keyS, PhysicalKeyboardKey.keyS, down: false);
    sendKey(
      LogicalKeyboardKey.superKey,
      PhysicalKeyboardKey.superKey,
      down: false,
    );
    await tester.pump();

    expect(forwarded, [NavigationDirection.down]);
  });
}
