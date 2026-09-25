import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/screen/model/screen.serializable.dart';

/// Total flex the screens of one monitor are normalised to.
///
/// Flutter's `Flex` only looks at the ratio between its children's flex
/// values, so the absolute total is free. Pinning it to a constant makes the
/// redistribution deterministic and lets the tests assert exact totals; the
/// split itself stays stable no matter how many screens are added or removed.
const monitorLayoutTotalFlex = 100;

/// Returns [layout] with a new screen appended for [screenId].
///
/// The new screen takes an equal share of [monitorLayoutTotalFlex], and the
/// existing screens are rescaled proportionally to fill the remainder: their
/// relative sizes are preserved and the list keeps summing to
/// [monitorLayoutTotalFlex]. [primaryForMonitor] is only used when [layout] is
/// empty, so the first screen of a monitor becomes its primary screen.
IList<ScreenConfiguration> addScreenToLayout(
  IList<ScreenConfiguration> layout,
  ScreenId screenId, {
  MonitorId? primaryForMonitor,
}) {
  if (layout.isEmpty) {
    return [
      ScreenConfiguration(
        flex: monitorLayoutTotalFlex,
        screenId: screenId,
        primaryForMonitor: primaryForMonitor,
      ),
    ].lock;
  }

  final newFlex = monitorLayoutTotalFlex ~/ (layout.length + 1);
  final existingFlex = _apportion(
    layout.map((configuration) => configuration.flex).toList(),
    monitorLayoutTotalFlex - newFlex,
  );

  return [
    for (var i = 0; i < layout.length; i++)
      layout[i].copyWith(flex: existingFlex[i]),
    ScreenConfiguration(flex: newFlex, screenId: screenId),
  ].lock;
}

/// Returns [layout] without its last screen, rescaling the remaining screens
/// proportionally so they keep filling [monitorLayoutTotalFlex].
///
/// Removing the only screen yields an empty list: an empty monitor is a valid
/// state (the user emptied it) and is not reflowed.
IList<ScreenConfiguration> removeLastScreenFromLayout(
  IList<ScreenConfiguration> layout,
) {
  if (layout.isEmpty) {
    return layout;
  }
  if (layout.length == 1) {
    return layout.removeLast();
  }

  final remaining = layout.removeLast();
  final flex = _apportion(
    remaining.map((configuration) => configuration.flex).toList(),
    monitorLayoutTotalFlex,
  );

  return [
    for (var i = 0; i < remaining.length; i++)
      remaining[i].copyWith(flex: flex[i]),
  ].lock;
}

/// Splits [total] across [weights] proportionally, using the largest-remainder
/// method so the result sums to exactly [total].
///
/// An exact total is what keeps the layout from drifting over repeated
/// additions and removals. When every weight is zero the split is as equal as
/// possible.
List<int> _apportion(List<int> weights, int total) {
  if (weights.isEmpty) {
    return const [];
  }

  final weightSum = weights.fold(0, (sum, weight) => sum + weight);
  if (weightSum <= 0) {
    final share = total ~/ weights.length;
    final remainder = total - share * weights.length;
    return [
      for (var i = 0; i < weights.length; i++) share + (i < remainder ? 1 : 0),
    ];
  }

  final result = [for (final weight in weights) (weight * total) ~/ weightSum];
  var remaining = total - result.fold(0, (sum, value) => sum + value);
  final byRemainder = [
    for (var i = 0; i < weights.length; i++)
      ((weights[i] * total) % weightSum, i),
  ]..sort((a, b) => b.$1.compareTo(a.$1));

  var index = 0;
  while (remaining > 0) {
    result[byRemainder[index % byRemainder.length].$2]++;
    remaining--;
    index++;
  }
  return result;
}
