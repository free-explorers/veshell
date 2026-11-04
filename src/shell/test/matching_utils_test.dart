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

  group('titleMatchingCost generic titles', () {
    const specific = 'opencode - veshell - Code - OSS';
    const video = 'opencode - veshell_video - Code - OSS';

    test('an application-name startup title is not a perfect match', () {
      // The shorter title is fully contained in the stored specific title, but
      // it carries no instance identity: it must stay a weak signal.
      expect(titleMatchingCost(specific, 'Code - OSS'), 50);
      expect(isGenericTitle('Code - OSS', specific), isTrue);
    });

    test('a stored application name keeps the near match', () {
      // A fresh tile stores its desktop-entry name: it must not lose the
      // window it launched to a sibling sharing only the app suffix.
      expect(titleMatchingCost('Code - OSS', specific), 1);
      // The helper is directional: a specific title is not generic relative to
      // the shorter application name.
      expect(isGenericTitle(specific, 'Code - OSS'), isFalse);
    });

    test('a restored workspace title keeps the graded near match', () {
      final cost = titleMatchingCost(
        video,
        'Navigation2.mp4 - veshell_video - Code - OSS',
      );
      expect(cost, lessThan(25));
      expect(
        isGenericTitle('Navigation2.mp4 - veshell_video - Code - OSS', video),
        isFalse,
      );
    });

    test('a short but specific title is not generic', () {
      expect(isGenericTitle('Downloads', 'Downloads — Files'), isFalse);
      expect(titleMatchingCost('Downloads', 'Downloads — Files'), lessThan(5));
    });

    test('equal titles are an exact match, not a generic one', () {
      expect(isGenericTitle(specific, specific), isFalse);
      expect(titleMatchingCost(specific, specific), 0);
    });
  });
}
