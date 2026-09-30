import 'package:flutter_test/flutter_test.dart';
import 'package:shell/shared/util/selection.dart';

void main() {
  group('nextSelectionIndex', () {
    test('returns -1 for an empty list', () {
      expect(nextSelectionIndex(currentIndex: -1, delta: 1, length: 0), -1);
    });

    test('selects the first entry when nothing is selected', () {
      expect(nextSelectionIndex(currentIndex: -1, delta: 1, length: 3), 0);
      expect(nextSelectionIndex(currentIndex: -1, delta: -1, length: 3), 0);
    });

    test('moves by the delta', () {
      expect(nextSelectionIndex(currentIndex: 0, delta: 1, length: 3), 1);
      expect(nextSelectionIndex(currentIndex: 2, delta: -1, length: 3), 1);
    });

    test('clamps at the ends', () {
      expect(nextSelectionIndex(currentIndex: 0, delta: -1, length: 3), 0);
      expect(nextSelectionIndex(currentIndex: 2, delta: 1, length: 3), 2);
      expect(nextSelectionIndex(currentIndex: 1, delta: 10, length: 3), 2);
    });
  });
}
