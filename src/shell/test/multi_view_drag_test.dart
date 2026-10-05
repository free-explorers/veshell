import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/cross_reorderable_list.dart';
import 'package:shell/shared/widget/multi_view_drag.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/persistent_window.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';

/// A second independently laid-out Flutter view using the test engine's
/// backing view for rendering. Hit tests are still keyed by its own view id.
class _SecondView extends TestFlutterView {
  _SecondView(WidgetTester tester)
    : super(
        view: tester.view,
        platformDispatcher: tester.platformDispatcher,
        display: tester.view.display,
      );

  @override
  int get viewId => 42;
}

void main() {
  testWidgets('a window tab survives source rebuild during a cross-view drag', (
    tester,
  ) async {
    final revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    final otherView = _SecondView(tester)
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 600);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    PersistentWindowId? dropped;
    await tester.pumpWidget(
      ViewCollection(
        views: [
          View(
            view: tester.view,
            child: MaterialApp(
              home: Scaffold(
                body: ShellDragView(
                  origin: Offset.zero,
                  child: ValueListenableBuilder<int>(
                    valueListenable: revision,
                    builder: (_, value, child) => CrossReorderableList<Tileable>(
                      // WorkspaceWidget recreates these widgets when monitor focus
                      // changes. Their window ids, not widget instances, are keys.
                      dataList: [
                        PersistentWindowTileable(
                          windowId: const PersistentWindowId('w1'),
                          isSelected: value == 0,
                        ),
                        PersistentWindowTileable(
                          windowId: const PersistentWindowId('w2'),
                          isSelected: value != 0,
                        ),
                      ],
                      itemKey: (data) =>
                          ValueKey((data as PersistentWindowTileable).windowId),
                      itemBuilder: (_, data) => SizedBox(
                        height: 100,
                        child: Text(
                          (data as PersistentWindowTileable).windowId.uuid,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          View(
            view: otherView,
            child: MaterialApp(
              home: Scaffold(
                body: ShellDragView(
                  origin: const Offset(800, 0),
                  child: ShellDragTarget<PersistentWindowTileable>(
                    onAcceptWithDetails: (details) =>
                        dropped = details.data.windowId,
                    builder: (_, candidates, rejected) =>
                        const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      wrapWithView: false,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('w1')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    revision.value++;
    await tester.pump();
    await gesture.moveTo(const Offset(1000, 200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(dropped, const PersistentWindowId('w1'));
  });

  for (final (origin, scale, cancel, targetKind) in [
    (const Offset(800, 0), 1.0, false, 'button'),
    (const Offset(-800, 0), 2.0, false, 'button'),
    (const Offset(0, 600), 1.5, false, 'button'),
    (const Offset(800, 0), 1.0, true, 'button'),
    (const Offset(800, 0), 1.0, false, 'list'),
    (const Offset(800, 0), 1.0, true, 'list'),
    (const Offset(800, 0), 1.0, false, 'blank'),
    (const Offset(800, 0), 1.0, false, 'empty'),
    (const Offset(800, 0), 1.0, false, 'launcher'),
  ]) {
    final listTarget = targetKind != 'button';
    testWidgets(
      'cross-view drag: $origin scale=$scale cancel=$cancel target=$targetKind',
      (tester) async {
        final otherView = _SecondView(tester)
          ..devicePixelRatio = scale
          ..physicalSize = const Size(800, 600) * scale;
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(800, 600);
        addTearDown(tester.view.reset);
        List<int>? source;
        List<int>? destination;
        int? dropped;
        await tester.pumpWidget(
          ViewCollection(
            views: [
              View(
                view: tester.view,
                child: MaterialApp(
                  home: Scaffold(
                    body: ShellDragView(
                      origin: Offset.zero,
                      child: CrossReorderableList<int>(
                        dataList: const [0, 1],
                        itemBuilder: (_, data) =>
                            SizedBox(height: 100, child: Text('source-$data')),
                        onListChanged: (list) => source = list,
                      ),
                    ),
                  ),
                ),
              ),
              View(
                view: otherView,
                child: MaterialApp(
                  home: Scaffold(
                    body: ShellDragView(
                      origin: origin,
                      child: listTarget
                          ? CrossReorderableList<int>(
                              dataList: switch (targetKind) {
                                'empty' => const [],
                                'launcher' => const [3],
                                _ => const [2, 3],
                              },
                              itemBuilder: (_, data) => SizedBox(
                                height: 100,
                                child: Text('destination-$data'),
                              ),
                              onListChanged: (list) => destination = list,
                            )
                          : ShellDragTarget<int>(
                              onAcceptWithDetails: (details) =>
                                  dropped = details.data,
                              builder: (_, candidates, rejected) =>
                                  const SizedBox.expand(),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          wrapWithView: false,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('source-0')),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        final y = ['blank', 'empty', 'launcher'].contains(targetKind)
            ? 350.0
            : 130.0;
        await gesture.moveTo(origin + Offset(200, y));
        await tester.pump();
        await gesture.moveTo(origin + Offset(200, y + 10));
        await tester.pump();
        expect(dropped, isNull);
        expect(source, isNull);
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(dropped, cancel || listTarget ? isNull : 0);
        final expected = switch (targetKind) {
          'empty' => [0],
          'launcher' => [0, 3],
          _ => [2, 0, 3],
        };
        expect(destination, !cancel && listTarget ? expected : isNull);
        expect(source, cancel ? isNull : [1]);
        if (cancel) expect(find.text('destination-0'), findsNothing);
      },
    );
  }
}
