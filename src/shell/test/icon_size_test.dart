import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/util/icon_size.dart';

void main() {
  group('iconPhysicalBucket', () {
    test('scales the logical size by the device pixel ratio', () {
      expect(iconPhysicalBucket(24, 1), 24);
      expect(iconPhysicalBucket(24, 2), 48);
      expect(iconPhysicalBucket(24, 3), 96);
    });

    test('snaps up to the next bucket', () {
      expect(iconPhysicalBucket(17, 1), 24);
      expect(iconPhysicalBucket(33, 1), 48);
      expect(iconPhysicalBucket(65, 1), 96);
    });

    test('collapses adjacent layout sizes onto one bucket', () {
      expect(iconPhysicalBucket(23, 1), iconPhysicalBucket(24, 1));
      expect(iconPhysicalBucket(40, 1), iconPhysicalBucket(42, 1));
    });

    test('keeps exact bucket sizes', () {
      for (final bucket in iconPixelBuckets) {
        expect(iconPhysicalBucket(bucket.toDouble(), 1), bucket);
      }
    });

    test('clamps to the largest bucket', () {
      expect(iconPhysicalBucket(1000, 4), iconPixelBuckets.last);
    });
  });
}
