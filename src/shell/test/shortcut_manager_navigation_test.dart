import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/shortcut_manager/widget/shortcut_manager.dart';
import 'package:shell/wayland/widget/surface/surface_focus.dart';

/// Regression tests for `Super+Arrow` navigation.
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
///  * `SurfaceFocus` bound the bare keys with `SingleActivator`, which matched
///    even with Super held and (with `consumesKey == false`) returned
///    `skipRemainingHandlers`, handing the chord to the client. The bare
///    bindings now use exact `LogicalKeySet`s.
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

  final navigation = <ShortcutActivator, Intent>{
    LogicalKeySet.fromSet({
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
  }) async {
    final forwarded = <NavigationDirection>[];
    final container = ProviderContainer(
      overrides: [hotkeysActivatorProvider.overrideWithValue(navigation)],
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
    // `SurfaceFocus` used to swallow the chord and hand it to the client.
    final forwarded = await pumpMonitor(
      tester,
      body: const Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: SurfaceFocus(child: Focus(autofocus: true, child: SizedBox())),
        ),
      ),
    );

    await pressSuperArrowDown(tester);

    expect(forwarded, [NavigationDirection.down]);
  });

  testWidgets('a client surface still forwards plain arrows to the client', (
    tester,
  ) async {
    // The `SurfaceFocus` change must not regress the plain-arrow pass-through:
    // returning `skipRemainingHandlers` means the key is not handled by the
    // shell and is returned to the platform for the client.
    await pumpMonitor(
      tester,
      body: const Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: SurfaceFocus(child: Focus(autofocus: true, child: SizedBox())),
        ),
      ),
    );

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
