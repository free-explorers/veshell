import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/physical_pixel_snap.dart';
import 'package:shell/wayland/model/wl_surface.dart';

void main() {
  group('surfaceLogicalSize', () {
    test('a fractional-aware buffer is divided by the window scale', () {
      expect(
        surfaceLogicalSize(const Size(1250, 625), 1, 1.25),
        const Size(1000, 500),
      );
    });

    test('an integer buffer scale wins over the fractional output scale', () {
      // A client without fractional-scale support on a 1.25 output reads
      // `wl_output.scale` 2 and commits a 2x buffer.
      expect(
        surfaceLogicalSize(const Size(800, 400), 2, 1.25),
        const Size(400, 200),
      );
    });
  });

  group('PhysicalPixelSnap', () {
    const snapKey = Key('snap');
    const childKey = Key('child');

    Widget snapAt(Offset origin, {double scale = 1}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: origin.dx,
              top: origin.dy,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: const PhysicalPixelSnap(
                  key: snapKey,
                  child: SizedBox(key: childKey, width: 10, height: 10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Offset physicalOrigin(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(childKey)) * tester.view.devicePixelRatio;

    testWidgets('moves a fractional origin onto the physical grid', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.25;
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1 logical px is 1.25 physical px; 3 is 3.75.
      await tester.pumpWidget(snapAt(const Offset(1, 3)));

      final origin = physicalOrigin(tester);
      expect(origin.dx, moreOrLessEquals(1));
      expect(origin.dy, moreOrLessEquals(4));
    });

    testWidgets('leaves an aligned origin alone', (tester) async {
      tester.view.devicePixelRatio = 1.25;
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(snapAt(const Offset(4, 8)));

      expect(physicalOrigin(tester), const Offset(5, 10));
    });

    testWidgets('does not shift a scaled surface', (tester) async {
      tester.view.devicePixelRatio = 1.25;
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(snapAt(const Offset(1, 3), scale: 0.5));

      expect(physicalOrigin(tester), const Offset(1.25, 3.75));
    });

    testWidgets('re-snaps after an ancestor moves', (tester) async {
      tester.view.devicePixelRatio = 1.25;
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(snapAt(const Offset(4, 8)));
      await tester.pumpWidget(snapAt(const Offset(1, 8)));
      await tester.pump();

      expect(physicalOrigin(tester).dx, moreOrLessEquals(1));
      final render = tester.renderObject<RenderPhysicalPixelSnap>(
        find.byKey(snapKey),
      );
      expect(render.debugNeedsPaint, isFalse);
    });
  });
}
