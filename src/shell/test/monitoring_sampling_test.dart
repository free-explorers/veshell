import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

void main() {
  test('startPolling samples immediately, never overlaps, and stops', () {
    fakeAsync((async) {
      var started = 0;
      var completed = 0;
      final cancel = startPolling(const Duration(milliseconds: 500), () async {
        started++;
        await Future<void>.delayed(const Duration(milliseconds: 800));
        completed++;
      });

      // The first sample does not wait for a full interval.
      async.elapse(const Duration(milliseconds: 1));
      expect(started, 1);

      // It finishes at t=800; the next tick waits a full interval after that.
      async.elapse(const Duration(milliseconds: 799));
      expect(completed, 1);
      expect(started, 1);

      async.elapse(const Duration(milliseconds: 500)); // t=1300
      expect(started, 2);

      cancel();
      async.elapse(const Duration(seconds: 10));
      expect(started, 2);
    });
  });
}
