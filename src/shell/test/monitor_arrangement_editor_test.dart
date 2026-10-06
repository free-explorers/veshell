import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/monitor/provider/monitor_arrangement.dart';
import 'package:shell/monitor/provider/monitor_placement.dart';
import 'package:shell/monitor/widget/monitor_arrangement/monitor_arrangement_canvas.dart';
import 'package:shell/monitor/widget/monitor_arrangement/monitor_arrangement_editor.dart';

const _placements = [
  MonitorPlacement(
    monitorId: 'A',
    description: 'A',
    logicalSize: Size(1920, 1080),
    location: Offset.zero,
    scale: 1,
  ),
  MonitorPlacement(
    monitorId: 'B',
    description: 'B',
    logicalSize: Size(1920, 1080),
    location: Offset(1920, 0),
    scale: 1,
  ),
];

void main() {
  testWidgets('the drag survives the overlap warning appearing mid-drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [monitorPlacementsProvider.overrideWithValue(_placements)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MonitorArrangementEditor(),
            ),
          ),
        ),
      ),
    );

    final tileA = find.descendant(
      of: find.byType(MonitorArrangementCanvas),
      matching: find.text('A'),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(tileA),
      kind: PointerDeviceKind.mouse,
    );
    // The first steps move A over B, so the warning appears while the drag is
    // still in progress.
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    expect(
      find.text('Monitors overlap. Move them apart to apply.'),
      findsOneWidget,
    );
    final xWhenWarningShown = tester.getTopLeft(tileA).dx;

    for (var i = 0; i < 25; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // If the canvas were remounted (or the recognizer lost) when the warning
    // appeared, the drag would have stopped there and A would not have moved
    // further.
    expect(tester.getTopLeft(tileA).dx, greaterThan(xWhenWarningShown + 100));
  });

  testWidgets('lays out without overflow at any height', (tester) async {
    // The expand hero animates the editor from the tile height to its full
    // height, so it must not overflow while the available height is still
    // small.
    for (final height in [0.0, 40.0, 200.0, 420.0]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [monitorPlacementsProvider.overrideWithValue(_placements)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 500,
                  height: height,
                  child: const MonitorArrangementEditor(),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    }
  });
}
