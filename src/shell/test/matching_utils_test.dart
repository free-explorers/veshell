import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';

/// Minimal [Window] for cost tests: the score comes entirely from the
/// [MatchingInfo] arguments, the window itself is not read.
class _FakeWindow extends Window {
  const _FakeWindow();

  @override
  WindowId get windowId => const WindowId.persistent('tile');

  @override
  WindowProperties get properties => const WindowProperties(appId: 'firefox');

  @override
  MetaWindowId? get metaWindowId => null;
}

void main() {
  group('matchesOutputSize', () {
    test('matches an exact monitor size', () {
      expect(
        matchesOutputSize(const Size(1920, 1080), const [Size(1920, 1080)]),
        isTrue,
      );
    });

    test('matches within the rounding tolerance', () {
      expect(
        matchesOutputSize(const Size(1919.5, 1080.5), const [Size(1920, 1080)]),
        isTrue,
      );
    });

    test('rejects a size that differs beyond the tolerance', () {
      expect(
        matchesOutputSize(const Size(1918, 1080), const [Size(1920, 1080)]),
        isFalse,
      );
    });

    test('matches when any monitor in the set has the size', () {
      expect(
        matchesOutputSize(const Size(3840, 2160), const [
          Size(1920, 1080),
          Size(3840, 2160),
        ]),
        isTrue,
      );
    });

    test('rejects a same-area size with a different aspect ratio', () {
      expect(
        matchesOutputSize(const Size(1080, 1920), const [Size(1920, 1080)]),
        isFalse,
      );
    });

    test('never matches an unknown or empty window size', () {
      expect(matchesOutputSize(null, const [Size(1920, 1080)]), isFalse);
      expect(matchesOutputSize(Size.zero, const [Size(1920, 1080)]), isFalse);
      expect(
        matchesOutputSize(const Size(-1, 1080), const [Size(1920, 1080)]),
        isFalse,
      );
    });

    test('ignores non-positive monitor sizes', () {
      expect(
        matchesOutputSize(Size.zero, const [Size.zero, Size(1920, 1080)]),
        isFalse,
      );
      expect(matchesOutputSize(Size.zero, const [Size.zero]), isFalse);
    });
  });

  group('windowMatchingCost waiting bonus', () {
    const metaWindow = MatchingInfo(appId: 'firefox');
    final justLaunched = MatchingInfo(
      appId: 'firefox',
      waitingForAppSince: DateTime.now(),
    );
    const settled = MatchingInfo(appId: 'firefox');

    test('arms the gather bonus by default', () {
      final cost = windowMatchingCost(
        metaWindow,
        justLaunched,
        const _FakeWindow(),
      );
      expect(cost.waiting, inInclusiveRange(90, 100));
    });

    test('drops the gather bonus when ranking settled ownership', () {
      final waited = windowMatchingCost(
        metaWindow,
        justLaunched,
        const _FakeWindow(),
        includeWaiting: false,
      );
      final notWaited = windowMatchingCost(
        metaWindow,
        settled,
        const _FakeWindow(),
        includeWaiting: false,
      );
      expect(waited.waiting, 0);
      // A still-gathering sibling is not cheaper than a settled one.
      expect(waited.total, notWaited.total);
    });
  });
}
