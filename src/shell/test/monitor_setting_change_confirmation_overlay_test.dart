import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/settings/provider/state/monitor_setting_change_confirmation.dart';
import 'package:shell/settings/widget/monitor_setting_change_confirmation_overlay.dart';

void main() {
  testWidgets('the scrim takes focus and swallows keys from behind it', (
    tester,
  ) async {
    final settingsKeys = <KeyEvent>[];
    final settingsFocus = FocusNode();
    final showScrim = ValueNotifier(false);
    addTearDown(settingsFocus.dispose);
    addTearDown(showScrim.dispose);

    final pending = MonitorSettingChange(
      monitorId: 'DP-1',
      description: 'Transform of DP-1',
      previous: const {},
      next: const {},
      deadline: DateTime.now().add(const Duration(seconds: 15)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monitorSettingChangeConfirmationProvider.overrideWithValue(pending),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showScrim,
            builder: (context, value, _) => Stack(
              children: [
                // Stands in for the settings search: it is focused when the
                // change is made and reacts to keys while it has focus.
                Focus(
                  focusNode: settingsFocus,
                  onKeyEvent: (node, event) {
                    settingsKeys.add(event);
                    return KeyEventResult.ignored;
                  },
                  child: const SizedBox.expand(),
                ),
                if (value) const MonitorSettingChangeConfirmationOverlay(),
              ],
            ),
          ),
        ),
      ),
    );

    settingsFocus.requestFocus();
    await tester.pump();
    expect(settingsFocus.hasFocus, isTrue);

    // Control: with no scrim, the focused widget behind receives keys.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(settingsKeys, isNotEmpty);

    // Inserting the scrim steals focus and swallows every key.
    settingsKeys.clear();
    showScrim.value = true;
    await tester.pump();
    await tester.pump();
    expect(settingsFocus.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(settingsKeys, isEmpty);
  });
}
