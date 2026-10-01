import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/provider/now_date_time.dart';

void main() {
  // Regression: the clock provider refreshed itself by calling
  // `ref.invalidateSelf()` from its own periodic timer. Without an
  // `onDispose`, every rebuild leaked the previous timer, so the overview's
  // clock (which is only mounted while the overview is shown) accumulated one
  // never-cancelled periodic timer per second and grew without bound.
  test('NowDateTime cancels its periodic timer on rebuild and dispose', () {
    fakeAsync((async) {
      final container = ProviderContainer();

      // Keep the auto-dispose provider alive the way the clock widget does.
      final subscription = container.listen(nowDateTimeProvider, (_, _) {});

      // Let it refresh a few times.
      async.elapse(const Duration(seconds: 5));
      expect(
        async.periodicTimerCount,
        1,
        reason: 'only the live refresh timer may remain pending',
      );

      subscription.close();
      container.dispose();
      expect(
        async.periodicTimerCount,
        0,
        reason: 'disposing must cancel the refresh timer',
      );
    });
  });
}
