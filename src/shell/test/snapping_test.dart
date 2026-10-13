import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/util/snapping.dart';

void main() {
  test('snapToWholePixel rounds to the nearest logical pixel', () {
    expect(snapToWholePixel(10.0), 10.0);
    expect(snapToWholePixel(10.4), 10.0);
    expect(snapToWholePixel(10.5), 11.0);
    expect(snapToWholePixel(10.6), 11.0);
    expect(snapToWholePixel(-2.5), -3.0);
  });

  test('snapOffsetToWholePixels rounds both axes', () {
    expect(
      snapOffsetToWholePixels(const Offset(10.4, 20.6)),
      const Offset(10, 21),
    );
  });

  test('snapPageViewport keeps whole-pixel pages', () {
    // 2464 / 3 = 821.33: two pages would start off the grid.
    expect(snapPageViewport(2464, 3), 2463);
    expect(snapPageViewport(2464, 5), 2460);
    // Divisible viewports are untouched.
    expect(snapPageViewport(2464, 1), 2464);
    expect(snapPageViewport(2464, 2), 2464);
    // Unbounded or degenerate inputs are returned unchanged.
    expect(snapPageViewport(double.infinity, 3), double.infinity);
    expect(snapPageViewport(2464, 0), 2464);
    expect(snapPageViewport(2, 3), 2);
  });
}
