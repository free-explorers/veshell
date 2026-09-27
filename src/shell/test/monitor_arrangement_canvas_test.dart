import 'dart:ui';

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
}
