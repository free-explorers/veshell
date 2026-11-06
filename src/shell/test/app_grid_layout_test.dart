import 'package:flutter_test/flutter_test.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_grid.dart';

void main() {
  test('a tile fills its share of the width, 4:5', () {
    final tile = appGridTileSize(272, 2);
    expect(tile.width, 128);
    expect(tile.height, 160);
  });

  test('the column count fits tiles of at most 120 px, at least one', () {
    expect(appGridColumnCount(0), 1);
    expect(appGridColumnCount(120), 1);
    expect(appGridColumnCount(121), 2);
    expect(appGridColumnCount(256), 2);
    expect(appGridColumnCount(257), 3);
  });

  // Frequent: 0 1      (one short row)
  // All:      2 3 4
  //           5 6
  final cells = appGridCells([2, 5], 3);

  test('each section starts a new row', () {
    expect(cells.map((c) => (c.row, c.column)).toList(), [
      (0, 0), (0, 1), //
      (1, 0), (1, 1), (1, 2), //
      (2, 0), (2, 1),
    ]);
    expect(cells.map((c) => c.section).toSet(), {0, 1});
  });

  test('Down keeps the column, or takes the end of a shorter row', () {
    expect(appGridMoveVertically(cells, 1, 1), 3);
    expect(appGridMoveVertically(cells, 4, 1), 6);
    expect(appGridMoveVertically(cells, 5, 1), isNull);
  });

  test('Up crosses into a short section row', () {
    expect(appGridMoveVertically(cells, 4, -1), 1);
    expect(appGridMoveVertically(cells, 2, -1), 0);
    expect(appGridMoveVertically(cells, 0, -1), isNull);
  });
}
