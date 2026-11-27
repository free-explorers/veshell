import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/screen/widget/zen_collapse.dart';

void main() {
  Widget panel({required bool collapsed, VoidCallback? onTap}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ZenCollapse(
            key: const ValueKey('zen'),
            collapsed: collapsed,
            axis: Axis.horizontal,
            extent: 48,
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onTap,
              child: const SizedBox(width: 48, height: 100),
            ),
          ),
        ),
      );

  testWidgets('a collapsed panel keeps only its selection line', (
    tester,
  ) async {
    await tester.pumpWidget(panel(collapsed: false));
    expect(tester.getSize(find.byKey(const ValueKey('zen'))).width, 48);

    await tester.pumpWidget(panel(collapsed: true));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('zen'))).width,
      zenVisibleExtent,
    );

    await tester.pumpWidget(panel(collapsed: false));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('zen'))).width, 48);
  });

  testWidgets('a collapsed panel takes no pointer', (tester) async {
    var taps = 0;
    await tester.pumpWidget(panel(collapsed: true, onTap: () => taps++));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(1, 50));

    expect(taps, 0);
  });
}
