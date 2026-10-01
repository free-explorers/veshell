import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

void main() {
  test('startPolling never overlaps samples and stops on cancel', () {
    fakeAsync((async) {
      var started = 0;
      var completed = 0;
      final cancel = startPolling(const Duration(milliseconds: 500), () async {
        started++;
        await Future<void>.delayed(const Duration(milliseconds: 800));
        completed++;
      });

      async.elapse(const Duration(milliseconds: 500));
      expect(started, 1);

      // A slow sample must not let a second tick start underneath it.
      async.elapse(const Duration(milliseconds: 500));
      expect(started, 1);

      async.elapse(const Duration(milliseconds: 300));
      expect(completed, 1);

      async.elapse(const Duration(milliseconds: 500));
      expect(started, 2);

      cancel();
      async.elapse(const Duration(seconds: 5));
      expect(started, 2);
    });
  });
}
