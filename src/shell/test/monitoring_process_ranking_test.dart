import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/overview/helm/monitoring_panel/model/process_ranking.dart';

void main() {
  group('rankProcesses', () {
    test('drops rows below the visibility threshold', () {
      final ranked = rankProcesses(<int, double>{1: 0, 2: 0.005, 3: 5}.lock);

      expect(ranked.map((entry) => entry.key), [3]);
    });

    test('keeps a process exactly at the threshold', () {
      final ranked = rankProcesses(<int, double>{1: 0.01}.lock);

      expect(ranked.map((entry) => entry.key), [1]);
    });

    test('orders by value, then by pid', () {
      final ranked = rankProcesses(
        <int, double>{1: 5, 2: 5, 3: 9}.lock,
      );

      expect(ranked.map((entry) => entry.key), [3, 2, 1]);
      expect(ranked.map((entry) => entry.value), [9, 5, 5]);
    });
  });
}
