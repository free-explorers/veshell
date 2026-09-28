import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/window/model/window_id.serializable.dart';

void main() {
  const windowA = EphemeralWindowId('a');
  const windowB = EphemeralWindowId('b');
  const gone = EphemeralWindowId('gone');

  test('keeps the focused window while it is still present', () {
    expect(
      resolveOverviewFocusedWindow([windowA, windowB].lock, windowB),
      windowB,
    );
  });

  test('falls back to the first window when the focused one is gone', () {
    expect(
      resolveOverviewFocusedWindow([windowA, windowB].lock, gone),
      windowA,
    );
  });

  test('falls back to the first window when nothing is focused', () {
    expect(
      resolveOverviewFocusedWindow([windowA, windowB].lock, null),
      windowA,
    );
  });

  test('is null for an empty list', () {
    expect(
      resolveOverviewFocusedWindow(<EphemeralWindowId>[].lock, null),
      isNull,
    );
  });
}
