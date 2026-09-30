import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/cross_reorderable_list.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/persistent_window.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Material(child: child)),
);

/// Drags the item at [from] onto the bottom half of [to] with an immediate
/// (press and move) drag. A first small move starts the drag and lets the list
/// build its drop zones, then a second move lands on the target.
Future<void> _dragPast(
  WidgetTester tester,
  Finder from,
  Finder to, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final gesture = await tester.startGesture(tester.getCenter(from), kind: kind);
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(to) + const Offset(0, 40));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dragging an item reorders the list (plain item)', (
    tester,
  ) async {
    List<int>? changed;
    await tester.pumpWidget(
      _wrap(
        CrossReorderableList<int>(
          dataList: const [0, 1, 2],
          itemBuilder: (context, data) =>
              SizedBox(height: 100, child: Text('item-$data')),
          onListChanged: (list) => changed = list,
        ),
      ),
    );

    await _dragPast(tester, find.text('item-0'), find.text('item-1'));

    expect(changed, [1, 0, 2]);
  });

  testWidgets('a mouse drag reorders the list once past the threshold', (
    tester,
  ) async {
    List<int>? changed;
    await tester.pumpWidget(
      _wrap(
        CrossReorderableList<int>(
          dataList: const [0, 1, 2],
          itemBuilder: (context, data) =>
              SizedBox(height: 100, child: Text('item-$data')),
          onListChanged: (list) => changed = list,
        ),
      ),
    );

    await _dragPast(
      tester,
      find.text('item-0'),
      find.text('item-1'),
      kind: PointerDeviceKind.mouse,
    );

    expect(changed, [1, 0, 2]);
  });

  testWidgets('a small mouse movement does not start a drag', (tester) async {
    List<int>? changed;
    var dragStarted = false;
    await tester.pumpWidget(
      _wrap(
        CrossReorderableList<int>(
          dataList: const [0, 1, 2],
          // The item has a tap handler, like the real tile, so the drag
          // recognizer is not the only one in the gesture arena.
          itemBuilder: (context, data) => Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () {},
              child: SizedBox(height: 100, child: Text('item-$data')),
            ),
          ),
          onListChanged: (list) => changed = list,
          onDropInProgress: (value) => dragStarted = dragStarted || value,
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('item-0')),
      kind: PointerDeviceKind.mouse,
    );
    // Below the 8px drag threshold, but enough to have started a drag with
    // Flutter's default 1px precise-pointer slop.
    await gesture.moveBy(const Offset(0, 4));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dragStarted, isFalse);
    expect(changed, isNull);
  });

  testWidgets(
    'dragging an item reorders it even when the item owns the long press',
    (tester) async {
      List<int>? changed;
      await tester.pumpWidget(
        _wrap(
          CrossReorderableList<int>(
            dataList: const [0, 1, 2],
            // Mirrors the tileable panel item: a selectable InkWell whose long
            // press opens a menu. The drag must win once the pointer moves
            // past the threshold, while a stationary hold stays with the
            // InkWell.
            itemBuilder: (context, data) => Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {},
                onLongPress: () {},
                onSecondaryTap: () {},
                child: SizedBox(height: 100, child: Text('item-$data')),
              ),
            ),
            onListChanged: (list) => changed = list,
          ),
        ),
      );

      await _dragPast(tester, find.text('item-0'), find.text('item-1'));

      expect(changed, [1, 0, 2]);
    },
  );

  testWidgets('a tap still selects the item and does not reorder', (
    tester,
  ) async {
    List<int>? changed;
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        CrossReorderableList<int>(
          dataList: const [0, 1, 2],
          itemBuilder: (context, data) => Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => tapped = true,
              child: SizedBox(height: 100, child: Text('item-$data')),
            ),
          ),
          onListChanged: (list) => changed = list,
        ),
      ),
    );

    await tester.tap(find.text('item-0'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(changed, isNull);
  });

  testWidgets(
    'a stationary long press is left to the item and does not reorder',
    (tester) async {
      List<int>? changed;
      var longPressed = false;
      await tester.pumpWidget(
        _wrap(
          CrossReorderableList<int>(
            dataList: const [0, 1, 2],
            itemBuilder: (context, data) => Material(
              type: MaterialType.transparency,
              child: InkWell(
                onLongPress: () => longPressed = true,
                child: SizedBox(height: 100, child: Text('item-$data')),
              ),
            ),
            onListChanged: (list) => changed = list,
          ),
        ),
      );

      await tester.longPress(find.text('item-0'));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
      expect(changed, isNull);
    },
  );

  testWidgets('dragging an item can drop it onto a target outside the list', (
    tester,
  ) async {
    int? dropped;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            SizedBox(
              height: 100,
              width: 200,
              child: DragTarget<int>(
                key: const ValueKey('drop-target'),
                onAcceptWithDetails: (details) => dropped = details.data,
                builder: (context, candidateData, rejectedData) =>
                    const ColoredBox(
                      color: Colors.blue,
                      child: SizedBox.expand(),
                    ),
              ),
            ),
            Expanded(
              child: CrossReorderableList<int>(
                dataList: const [0, 1, 2],
                itemBuilder: (context, data) =>
                    SizedBox(height: 50, child: Text('item-$data')),
              ),
            ),
          ],
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('item-0')),
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('drop-target'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dropped, 0);
  });

  testWidgets(
    'a window tileable can be dropped on a PersistentWindowTileable target',
    (tester) async {
      PersistentWindowId? dropped;
      final windows = [
        const PersistentWindowTileable(
          windowId: PersistentWindowId('w1'),
          isSelected: false,
        ),
        const PersistentWindowTileable(
          windowId: PersistentWindowId('w2'),
          isSelected: false,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              SizedBox(
                height: 100,
                width: 200,
                child: DragTarget<PersistentWindowTileable>(
                  key: const ValueKey('workspace-target'),
                  onAcceptWithDetails: (details) =>
                      dropped = details.data.windowId,
                  builder: (context, candidateData, rejectedData) =>
                      const ColoredBox(
                        color: Colors.blue,
                        child: SizedBox.expand(),
                      ),
                ),
              ),
              Expanded(
                child: CrossReorderableList<Tileable>(
                  dataList: windows,
                  itemBuilder: (context, data) {
                    final tileable = data as PersistentWindowTileable;
                    return Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () {},
                        child: SizedBox(
                          height: 50,
                          child: Text('tile-${tileable.windowId.uuid}'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('tile-w1')),
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('workspace-target'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(dropped?.uuid, 'w1');
    },
  );
}
