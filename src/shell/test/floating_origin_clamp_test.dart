import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/window/widget/floatable_window.dart';

void main() {
  const available = Size(800, 600);

  test('a smaller floating window can move half its size outside', () {
    expect(
      clampFloatingOrigin(
        available,
        const Size(300, 200),
        const Offset(900, 900),
      ),
      const Offset(650, 500),
    );
    expect(
      clampFloatingOrigin(
        available,
        const Size(300, 200),
        const Offset(-500, -500),
      ),
      const Offset(-150, -100),
    );
  });

  test('a viewport-sized floating window can be dragged', () {
    expect(
      clampFloatingOrigin(available, available, const Offset(100, 120)),
      const Offset(100, 120),
    );
    expect(
      clampFloatingOrigin(available, available, const Offset(-2000, 2000)),
      const Offset(-400, 300),
    );
  });

  test('an oversized floating window can move half its size outside', () {
    expect(
      clampFloatingOrigin(
        available,
        const Size(1000, 800),
        const Offset(-2000, 2000),
      ),
      const Offset(-500, 200),
    );
  });
}
