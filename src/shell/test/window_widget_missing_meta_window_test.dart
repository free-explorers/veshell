import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/window/widget/window.dart';

void main() {
  testWidgets(
    'a tile whose meta window is gone renders nothing instead of throwing',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WindowWidget(
                metaWindowId: 'gone-window',
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      // The MetaWindowState for `gone-window` was never created, so it throws
      // by design. WindowWidget must swallow that and render nothing rather
      // than replace the whole tile — close affordances included — with the
      // error widget: the blank, unclosable tile.
      expect(tester.takeException(), isNull);
      expect(find.byType(WindowWidget), findsOneWidget);
      expect(find.byType(MetaSurfaceWidget), findsNothing);
    },
  );
}
