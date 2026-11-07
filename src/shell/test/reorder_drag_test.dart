import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/util/reorder_drag.dart';
import 'package:shell/shared/widget/cross_reorderable_list.dart';
import 'package:shell/tile_grab/widget/tile_grab_cursor.dart';

void main() {
  test('counts concurrent panel reorders', () {
    final drag = ReorderDragController.instance;
    addTearDown(() {
      while (drag.isDragging.value) {
        drag.end();
      }
    });

    expect(drag.isDragging.value, isFalse);
    drag.begin();
    expect(drag.isDragging.value, isTrue);
    drag.begin();
    expect(drag.isDragging.value, isTrue);
    drag.end();
    expect(drag.isDragging.value, isTrue);
    drag.end();
    expect(drag.isDragging.value, isFalse);
    drag.end();
    expect(drag.isDragging.value, isFalse);
  });

  testWidgets(
    'a panel reorder raises the dragging state until it is released',
    (tester) async {
      final drag = ReorderDragController.instance;
      addTearDown(() {
        while (drag.isDragging.value) {
          drag.end();
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: CrossReorderableList<int>(
                dataList: const [0, 1],
                itemBuilder: (_, data) =>
                    SizedBox(height: 100, child: Text('item-$data')),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('item-0')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(drag.isDragging.value, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(drag.isDragging.value, isFalse);
    },
  );

  testWidgets(
    'the monitor cursor shows grabbing while a panel item is dragged',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(children: [TileGrabCursor()]),
          ),
        ),
      );
      MouseCursor cursor() => tester
          .widget<MouseRegion>(
            find.descendant(
              of: find.byType(TileGrabCursor),
              matching: find.byType(MouseRegion),
            ),
          )
          .cursor;

      expect(cursor(), MouseCursor.defer);
      ReorderDragController.instance.begin();
      await tester.pump();
      expect(cursor(), SystemMouseCursors.grabbing);
      ReorderDragController.instance.end();
      await tester.pump();
      expect(cursor(), MouseCursor.defer);
    },
  );
}
