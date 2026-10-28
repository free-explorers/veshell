import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/lock_screen/model/lock_screen_state/lock_screen_state.dart';
import 'package:shell/lock_screen/provider/lock_screen.dart';
import 'package:shell/lock_screen/widget/lock_screen_overlay.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/focused_monitor.dart';

import 'support/finders.dart';

class _Locked extends LockScreen {
  @override
  LockScreenState build() => const LockScreenState(
    locked: true,
    userName: 'ada',
    prompt: 'Password: ',
  );
}

final _monitor = Monitor(
  name: 'm',
  description: '',
  physicalProperties: const PhysicalProperties(
    size: Size.zero,
    make: '',
    model: '',
  ),
  scale: 1,
  location: Offset.zero,
  currentMode: null,
  preferredMode: null,
  modes: const [],
  viewId: 0,
);

/// Mounts the lock screen where `MonitorWidget` does: in the app builder,
/// beside the Navigator, over a desktop that held the keyboard.
Future<void> _pumpLockScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lockScreenProvider.overrideWith(_Locked.new),
        focusedMonitorProvider.overrideWithValue(_monitor),
      ],
      child: MaterialApp(
        localizationsDelegates: shellLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            LockScreenBlur(child: child ?? const SizedBox.shrink()),
            const LockScreenOverlay(monitorName: 'm'),
          ],
        ),
        home: const Material(child: TextField(autofocus: true)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _passwordField => find.byType(EditableText).last;

void main() {
  testWidgets('the password field takes the keyboard from the desktop', (
    tester,
  ) async {
    await _pumpLockScreen(tester);
    final field = tester.state<EditableTextState>(_passwordField);
    expect(field.widget.focusNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('Backspace deletes a character instead of reaching the '
      'compositor', (tester) async {
    await _pumpLockScreen(tester);
    await tester.enterText(_passwordField, 'abc');
    await tester.pump();

    // An unhandled Backspace is typed by the compositor's text-input
    // fallback; Flutter must consume it.
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.backspace), isTrue);
    await tester.pump();
    expect(
      tester.state<EditableTextState>(_passwordField).textEditingValue.text,
      'ab',
    );
  });

  testWidgets('the eye button shows the password and keeps the keyboard', (
    tester,
  ) async {
    await _pumpLockScreen(tester);
    EditableText field() => tester.widget<EditableText>(_passwordField);
    expect(field().obscureText, isTrue);

    await tester.tap(findIcon(MdiIcons.eyeOutline));
    await tester.pump();
    expect(field().obscureText, isFalse);
    expect(field().focusNode.hasPrimaryFocus, isTrue);

    await tester.tap(findIcon(MdiIcons.eyeOffOutline));
    await tester.pump();
    expect(field().obscureText, isTrue);
  });
}
