import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_arrangement.dart';

Monitor _monitor({
  required String name,
  required Size modeSize,
  required Offset location,
  double scale = 1,
}) {
  final mode = Mode(size: modeSize, refreshRate: 60000);
  return Monitor(
    name: name,
    description: '$name description',
    physicalProperties: PhysicalProperties(
      size: modeSize,
      make: 'make',
      model: 'model',
    ),
    scale: scale,
    location: location,
    currentMode: mode,
    preferredMode: mode,
    modes: [mode],
    viewId: 0,
  );
}

void main() {
  group('monitorLogicalSize', () {
    test('divides the physical mode by the fractional scale', () {
      final monitor = _monitor(
        name: 'DP-1',
        modeSize: const Size(3840, 2160),
        location: Offset.zero,
      );

      expect(monitorLogicalSize(monitor, 2), const Size(1920, 1080));
    });

    test('returns zero when the monitor has no current mode', () {
      final monitor = Monitor(
        name: 'DP-1',
        description: 'DP-1',
        physicalProperties: const PhysicalProperties(
          size: Size(1920, 1080),
          make: 'make',
          model: 'model',
        ),
        scale: 1,
        location: Offset.zero,
        currentMode: null,
        preferredMode: null,
        modes: const [],
        viewId: 0,
      );

      expect(monitorLogicalSize(monitor, 1), Size.zero);
    });

    test('swaps width and height when transposed', () {
      final monitor = _monitor(
        name: 'DP-1',
        modeSize: const Size(3840, 2160),
        location: Offset.zero,
      );

      expect(
        monitorLogicalSize(monitor, 2, transposed: true),
        const Size(1080, 1920),
      );
    });
  });

  group('boundingBoxOf', () {
    test('spans every rectangle', () {
      final box = boundingBoxOf([
        const Rect.fromLTWH(0, 0, 100, 100),
        const Rect.fromLTWH(200, -50, 100, 100),
      ]);

      expect(box, const Rect.fromLTRB(0, -50, 300, 100));
    });

    test('is zero for an empty input', () {
      expect(boundingBoxOf([]), Rect.zero);
    });
  });

  group('snapToNeighbours', () {
    test('aligns the moving right edge with the neighbour left edge', () {
      final result = snapToNeighbours(const Rect.fromLTWH(0, 0, 200, 100), [
        const Rect.fromLTWH(205, 0, 200, 100),
      ]);

      expect(result.location.dx, 5);
      expect(result.location.dy, 0);
      expect(result.verticalGuide, 205);
    });

    test('aligns top edges and reports the horizontal guide', () {
      final result = snapToNeighbours(const Rect.fromLTWH(0, 0, 200, 100), [
        const Rect.fromLTWH(300, 8, 200, 100),
      ]);

      expect(result.location.dy, 8);
      expect(result.horizontalGuide, isNotNull);
    });

    test('does not snap beyond the threshold', () {
      final result = snapToNeighbours(const Rect.fromLTWH(0, 0, 200, 100), [
        const Rect.fromLTWH(500, 500, 200, 100),
      ]);

      expect(result.location, Offset.zero);
      expect(result.verticalGuide, isNull);
      expect(result.horizontalGuide, isNull);
    });
  });

  group('arrangementsOverlap', () {
    test('treats touching edges as not overlapping', () {
      expect(
        arrangementsOverlap([
          const Rect.fromLTWH(0, 0, 100, 100),
          const Rect.fromLTWH(100, 0, 100, 100),
        ]),
        isFalse,
      );
    });

    test('detects an actual overlap', () {
      expect(
        arrangementsOverlap([
          const Rect.fromLTWH(0, 0, 100, 100),
          const Rect.fromLTWH(50, 0, 100, 100),
        ]),
        isTrue,
      );
    });
  });

  group('changedLocations', () {
    test('ignores sub-pixel moves', () {
      final changed = changedLocations(
        {'DP-1': Offset.zero},
        {'DP-1': const Offset(0.2, 0.2)},
      );

      expect(changed, isEmpty);
    });

    test('reports monitors moved beyond the tolerance', () {
      final changed = changedLocations(
        {'DP-1': Offset.zero},
        {'DP-1': const Offset(10, 0)},
      );

      expect(changed, {'DP-1': const Offset(10, 0)});
    });
  });

  group('toRelativeArrangement', () {
    test('translates the arrangement so its top-left is at the origin', () {
      final placements = [
        const MonitorPlacement(
          monitorId: 'A',
          description: 'A',
          logicalSize: Size(1920, 1080),
          location: Offset(100, 50),
          scale: 1,
        ),
        const MonitorPlacement(
          monitorId: 'B',
          description: 'B',
          logicalSize: Size(1920, 1080),
          location: Offset(2020, 50),
          scale: 1,
        ),
      ];

      final relative = toRelativeArrangement(placements);

      expect(relative[0].location, Offset.zero);
      expect(relative[1].location, const Offset(1920, 0));
    });

    test('leaves an empty arrangement unchanged', () {
      expect(toRelativeArrangement([]), isEmpty);
    });

    test('anchors negative arrangements at zero', () {
      final placements = [
        const MonitorPlacement(
          monitorId: 'A',
          description: 'A',
          logicalSize: Size(1920, 1080),
          location: Offset(-1920, 0),
          scale: 1,
        ),
        const MonitorPlacement(
          monitorId: 'B',
          description: 'B',
          logicalSize: Size(1920, 1080),
          location: Offset.zero,
          scale: 1,
        ),
      ];

      expect(
        arrangementOrigin(placements.map((p) => p.rect)),
        const Offset(-1920, 0),
      );
      expect(toRelativeArrangement(placements)[0].location, Offset.zero);
    });
  });

  group('MonitorPlacement.fromMonitor', () {
    test('derives the logical size and keeps the desired location', () {
      final placement = MonitorPlacement.fromMonitor(
        monitor: _monitor(
          name: 'DP-1',
          modeSize: const Size(3840, 2160),
          location: const Offset(100, 50),
        ),
        scale: 2,
      );

      expect(placement.monitorId, 'DP-1');
      expect(placement.logicalSize, const Size(1920, 1080));
      expect(placement.location, const Offset(100, 50));
      expect(placement.rect, const Rect.fromLTWH(100, 50, 1920, 1080));
    });
  });

  group('autoArrangement', () {
    test('lays placements left-to-right keeping their logical sizes', () {
      const a = MonitorPlacement(
        monitorId: 'A',
        description: 'A',
        logicalSize: Size(1920, 1080),
        location: Offset(400, 300),
        scale: 2,
      );
      const b = MonitorPlacement(
        monitorId: 'B',
        description: 'B',
        logicalSize: Size(2560, 1440),
        location: Offset(2320, 100),
        scale: 1,
      );

      final arranged = autoArrangement([a, b]);

      expect(arranged[0].location, Offset.zero);
      expect(arranged[0].logicalSize, const Size(1920, 1080));
      expect(arranged[0].scale, 2);
      expect(arranged[1].location, const Offset(1920, 0));
      expect(arranged[1].logicalSize, const Size(2560, 1440));
      expect(arranged[1].scale, 1);
    });
  });
}
