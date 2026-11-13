import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/wayland/widget/surface_visibility.dart';

/// A window texture as the shell draws it.
Widget _surface(int id) => SurfaceVisibilityProbe(
  surfaceId: id,
  child: const SizedBox(width: 100, height: 100),
);

void main() {
  late List<List<int>> reports;

  setUp(() {
    reports = [];
    SurfaceVisibilityTracker.instance.start(reports.add);
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [child]),
      ),
    );
    await tester.pump();
  }

  testWidgets('painted surfaces are visible, hidden ones are not', (
    tester,
  ) async {
    await pump(
      tester,
      Column(
        children: [
          _surface(1),
          Offstage(child: _surface(2)),
          Opacity(opacity: 0, child: _surface(3)),
          // Laid out but clipped away entirely.
          SizedBox(
            height: 0,
            child: ClipRect(child: OverflowBox(child: _surface(4))),
          ),
        ],
      ),
    );

    expect(reports.last, [1]);
  });

  testWidgets('a change is reported, an unchanged frame is not', (
    tester,
  ) async {
    await pump(tester, _surface(1));
    final afterFirst = reports.length;

    await tester.pump();
    expect(reports.length, afterFirst);

    await pump(tester, Offstage(child: _surface(1)));
    expect(reports.length, afterFirst + 1);
    expect(reports.last, isEmpty);
  });
}
