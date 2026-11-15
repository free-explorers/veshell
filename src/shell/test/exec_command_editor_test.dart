import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/window/widget/window_placeholder.dart';

void main() {
  testWidgets('a click outside the field keeps the edited command', (
    tester,
  ) async {
    String? saved;
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ExecCommandEditor(
                  maxWidth: 400,
                  originalExec: 'zotero -url %U',
                  onChanged: (exec) {
                    saved = exec;
                    calls++;
                  },
                ),
                const SizedBox(key: Key('outside'), width: 200, height: 200),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'zotero');
    await tester.tap(find.byKey(const Key('outside')));
    await tester.pump();

    expect(saved, 'zotero');
    expect(calls, 1);

    // Once saved, a further click outside does not submit again.
    await tester.tap(find.byKey(const Key('outside')));
    await tester.pump();
    expect(calls, 1);
  });
}
