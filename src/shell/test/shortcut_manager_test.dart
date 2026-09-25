import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/shortcut_manager/widget/shortcut_manager.dart';

void main() {
  testWidgets('focus-loss Super release does not open Overview', (
    tester,
  ) async {
    var overviewCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hotkeysActivatorProvider.overrideWithValue({})],
        child: VeshellShortcutManager(
          child: Actions(
            actions: {
              ToggleOverviewIntent: CallbackAction<ToggleOverviewIntent>(
                onInvoke: (_) {
                  overviewCount++;
                  return null;
                },
              ),
            },
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(primaryFocus, isNotNull);

    final keyboard = HardwareKeyboard.instance;
    void dispatch(KeyEvent event) {
      keyboard.handleKeyEvent(event);
      ServicesBinding.instance.keyEventManager.keyMessageHandler!(
        KeyMessage([event], null),
      );
    }

    const physical = PhysicalKeyboardKey.metaLeft;
    const logical = LogicalKeyboardKey.superKey;
    dispatch(
      KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
      ),
    );
    dispatch(
      KeyUpEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
        synthesized: true,
      ),
    );
    expect(overviewCount, 0);

    dispatch(
      KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
      ),
    );
    dispatch(
      KeyUpEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
      ),
    );
    expect(overviewCount, 1);
  });
}
