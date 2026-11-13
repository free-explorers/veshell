import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/wayland/widget/surface_visibility.dart';

/// A window texture as the shell draws it.
Widget _surface(int id) => SurfaceVisibilityProbe(
  surfaceId: id,
  child: const SizedBox(width: 100, height: 100),
);

void main() {
  late List<({List<int> visible, List<int> limited})> reports;

  setUp(() {
    reports = [];
    SurfaceVisibilityTracker.instance.start(
      (visible, limited) => reports.add((visible: visible, limited: limited)),
    );
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

    expect(reports.last.visible, [1]);
    expect(reports.last.limited, isEmpty);
  });

  testWidgets('a paused game is reported limited', (tester) async {
    await pump(
      tester,
      Row(
        children: [
          _surface(1),
          SurfaceFrameRateLimit(limited: true, child: _surface(7)),
        ],
      ),
    );

    expect(reports.last.visible, [1]);
    expect(reports.last.limited, [7]);
  });

  testWidgets('a paused game stays limited when it is not painted', (
    tester,
  ) async {
    await pump(
      tester,
      Offstage(child: SurfaceFrameRateLimit(limited: true, child: _surface(7))),
    );

    expect(reports.last.visible, isEmpty);
    expect(reports.last.limited, [7]);
  });

  testWidgets('a surface also shown at full rate is not limited', (
    tester,
  ) async {
    await pump(
      tester,
      Row(
        children: [
          SurfaceFrameRateLimit(limited: true, child: _surface(7)),
          _surface(7),
        ],
      ),
    );

    expect(reports.last.visible, [7]);
    expect(reports.last.limited, isEmpty);
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
    expect(reports.last.visible, isEmpty);
  });
}
