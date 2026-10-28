import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/physical_pixel_snap.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/widget/surface.dart';

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

    test('a viewport destination is the logical size', () {
      // Qt 6 at 1.2 renders a 1.2x buffer and declares its window size with
      // wp_viewport; its integer buffer scale (ceil(1.2) = 2) is ignored.
      expect(
        surfaceLogicalSize(
          const Size(1200, 600),
          2,
          1.2,
          viewportSize: const Size(1000, 500),
        ),
        const Size(1000, 500),
      );
    });
  });

  group('ViewportCrop', () {
    const childKey = Key('child');

    Widget crop(Rect? source) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 100,
          height: 50,
          child: ViewportCrop(
            bufferSize: const Size(400, 200),
            source: source,
            child: const SizedBox.expand(key: childKey),
          ),
        ),
      ),
    );

    testWidgets('without a source the whole buffer fills the box', (
      tester,
    ) async {
      await tester.pumpWidget(crop(null));
      expect(
        tester.getRect(find.byKey(childKey)),
        Offset.zero & const Size(100, 50),
      );
    });

    testWidgets('a source rectangle is stretched over the box', (tester) async {
      // Show buffer pixels (100, 50)..(300, 150) in a 100x50 box: half scale.
      await tester.pumpWidget(crop(const Rect.fromLTWH(100, 50, 200, 100)));
      expect(
        tester.getRect(find.byKey(childKey)),
        const Rect.fromLTWH(-50, -25, 200, 100),
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
