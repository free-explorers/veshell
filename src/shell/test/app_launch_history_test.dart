import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/model/app_launch_history.serializable.dart';

void main() {
  final start = DateTime.utc(2026);
  const empty = AppLaunchHistory();

  test('a launch weighs one, halving every half-life', () {
    final history = empty.withLaunch('a', start);
    final score = history.scores['a']!;
    expect(score.scoreAt(start), 1);
    expect(score.scoreAt(start.add(appLaunchHalfLife)), closeTo(0.5, 1e-9));
    expect(
      score.scoreAt(start.add(appLaunchHalfLife * 2)),
      closeTo(0.25, 1e-9),
    );
  });

  test('repeated launches add up, after decaying', () {
    final history = empty
        .withLaunch('a', start)
        .withLaunch('a', start.add(appLaunchHalfLife));
    expect(
      history.scores['a']!.scoreAt(start.add(appLaunchHalfLife)),
      closeTo(1.5, 1e-9),
    );
  });

  test('the most used rank first, and an old habit fades', () {
    var history = empty;
    for (var i = 0; i < 5; i++) {
      history = history.withLaunch('daily', start.add(Duration(hours: i)));
    }
    final soon = start.add(const Duration(days: 1));
    history = history.withLaunch('once', soon);
    expect(history.rankedIds(soon), ['daily', 'once']);

    // Five weeks later, a few launches of something new outrank the habit
    // that stopped.
    final later = start.add(appLaunchHalfLife * 5);
    history = history.withLaunch('new', later).withLaunch('new', later);
    expect(history.rankedIds(later).first, 'new');
  });

  test('a faded application is forgotten at the next launch', () {
    final later = start.add(appLaunchHalfLife * 6);
    final history = empty.withLaunch('old', start).withLaunch('new', later);
    expect(history.scores.keys, ['new']);
  });

  test('round-trips through JSON', () {
    final history = empty.withLaunch('a', start).withLaunch('b', start);
    expect(AppLaunchHistory.fromJson(history.toJson()), history);
  });

  test('a history without scores loads empty', () {
    expect(
      AppLaunchHistory.fromJson(const {
        'recentIds': ['a'],
      }).scores,
      isEmpty,
    );
  });
}
