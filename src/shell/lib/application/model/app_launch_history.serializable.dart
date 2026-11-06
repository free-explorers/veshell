import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_launch_history.serializable.freezed.dart';
part 'app_launch_history.serializable.g.dart';

/// How long a launch takes to weigh half as much ("frecency" half-life).
const appLaunchHalfLife = Duration(days: 7);

/// Below this weight an application is forgotten: a single launch fades out
/// after about a month without another.
const _forgottenScore = 0.05;

/// The most applications remembered at once.
const _maxRemembered = 64;

/// How often, and how lately, an application was launched.
@freezed
abstract class AppLaunchScore with _$AppLaunchScore {
  const factory AppLaunchScore({
    /// The launches' weight as of [lastLaunch]: each launch adds one, and the
    /// total halves every [appLaunchHalfLife].
    required double score,
    required DateTime lastLaunch,
  }) = _AppLaunchScore;
  const AppLaunchScore._();

  factory AppLaunchScore.fromJson(Map<String, dynamic> json) =>
      _$AppLaunchScoreFromJson(json);

  /// The weight as of [now].
  double scoreAt(DateTime now) {
    final elapsed = now.difference(lastLaunch);
    if (elapsed <= Duration.zero) {
      return score;
    }
    return score *
        math.pow(
          0.5,
          elapsed.inMilliseconds / appLaunchHalfLife.inMilliseconds,
        );
  }
}

/// The applications launched from the launchers, by desktop file ID, with
/// their frecency.
@freezed
abstract class AppLaunchHistory with _$AppLaunchHistory {
  const factory AppLaunchHistory({
    // Defaulted so a file without it (written before the scores existed)
    // loads as an empty history rather than failing to decode.
    @Default(IMapConst<String, AppLaunchScore>({}))
    IMap<String, AppLaunchScore> scores,
  }) = _AppLaunchHistory;
  const AppLaunchHistory._();

  factory AppLaunchHistory.fromJson(Map<String, dynamic> json) =>
      _$AppLaunchHistoryFromJson(json);

  /// The history after a launch of [id] at [now]; the applications that faded
  /// out are dropped.
  AppLaunchHistory withLaunch(String id, DateTime now) {
    final launched = AppLaunchScore(
      score: (scores[id]?.scoreAt(now) ?? 0) + 1,
      lastLaunch: now,
    );
    final kept =
        [
              for (final MapEntry(:key, :value) in scores.entries)
                if (key != id && value.scoreAt(now) >= _forgottenScore)
                  (id: key, score: value),
            ]
            .sortedBy<num>((entry) => -entry.score.scoreAt(now))
            .take(_maxRemembered - 1);
    return AppLaunchHistory(
      scores: {
        id: launched,
        for (final entry in kept) entry.id: entry.score,
      }.lock,
    );
  }

  /// The remembered applications, most used first as of [now].
  List<String> rankedIds(DateTime now) =>
      (scores.entries.toList()..sort(
            (a, b) => b.value.scoreAt(now).compareTo(a.value.scoreAt(now)),
          ))
          .map((entry) => entry.key)
          .toList();
}
