import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/monitor/provider/monitor_arrangement.dart';
import 'package:shell/monitor/widget/monitor_arrangement/monitor_arrangement_canvas.dart';

MonitorPlacement _placement(String id, Offset location) => MonitorPlacement(
  monitorId: id,
  description: id,
  logicalSize: const Size(1920, 1080),
  location: location,
  scale: 1,
);

Widget _canvas({required void Function(String, Offset) onChanged}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 500,
        child: MonitorArrangementCanvas(
          placements: [
            _placement('A', Offset.zero),
            _placement('B', const Offset(1920, 0)),
          ],
          selectedMonitorId: null,
          guides: null,
          onChanged: onChanged,
          onGuidesChanged: (_) {},
          onSelected: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a single large drag moves the monitor', (tester) async {
    final moved = <Offset>[];
    await tester.pumpWidget(
      _canvas(
        onChanged: (id, location) {
          if (id == 'A') moved.add(location);
        },
      ),
    );

    await tester.drag(find.text('A'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(moved, isNotEmpty);
    expect(moved.last.dx, lessThan(0));
  });

  testWidgets('many sub-threshold steps accumulate instead of snapping back', (
    tester,
  ) async {
    final moved = <Offset>[];
    await tester.pumpWidget(
      _canvas(
        onChanged: (id, location) {
          if (id == 'A') moved.add(location);
        },
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('A')),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 0; i < 40; i++) {
      await gesture.moveBy(const Offset(-1, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved, isNotEmpty);
    expect(moved.last.dx, lessThan(-1));
  });

  testWidgets('the mouse wheel zooms around the pointer', (tester) async {
    await tester.pumpWidget(_canvas(onChanged: (_, _) {}));

    final tileA = find.ancestor(
      of: find.text('A'),
      matching: find.byType(MonitorArrangementTile),
    );
    final before = tester.getSize(tileA);

    final center = tester.getCenter(find.byType(MonitorArrangementCanvas));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
    await tester.pumpAndSettle();

    expect(tester.getSize(tileA).width, greaterThan(before.width));
  });

  testWidgets('dragging empty space pans the view without moving a monitor', (
    tester,
  ) async {
    final moved = <Offset>[];
    await tester.pumpWidget(
      _canvas(
        onChanged: (id, location) {
          if (id == 'A') moved.add(location);
        },
      ),
    );

    final tileA = find.ancestor(
      of: find.text('A'),
      matching: find.byType(MonitorArrangementTile),
    );
    final canvas = tester.getRect(find.byType(MonitorArrangementCanvas));
    final beforeA = tester.getTopLeft(tileA);

    await tester.dragFrom(
      canvas.topLeft + const Offset(5, 5),
      const Offset(30, 20),
    );
    await tester.pumpAndSettle();

    expect(moved, isEmpty);
    expect(
      tester.getTopLeft(tileA) - beforeA,
      offsetMoreOrLessEquals(const Offset(30, 20), epsilon: 0.5),
    );
  });

  testWidgets('middle-dragging a monitor pans the view', (tester) async {
    final moved = <Offset>[];
    await tester.pumpWidget(
      _canvas(
        onChanged: (id, location) {
          if (id == 'A') moved.add(location);
        },
      ),
    );

    final tileA = find.ancestor(
      of: find.text('A'),
      matching: find.byType(MonitorArrangementTile),
    );
    final beforeA = tester.getTopLeft(tileA);

    final gesture = await tester.startGesture(
      tester.getCenter(tileA),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await gesture.moveBy(const Offset(25, 15));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved, isEmpty);
    expect(
      tester.getTopLeft(tileA) - beforeA,
      offsetMoreOrLessEquals(const Offset(25, 15), epsilon: 0.5),
    );
  });
}
