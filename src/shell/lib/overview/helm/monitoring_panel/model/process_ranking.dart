import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// Processes worth showing in a per-process list: those at or above
/// [minPercent], strongest first.
///
/// Rows that round to `0.00%` are noise, so they are dropped; ties break by
/// pid to keep the order stable between samples.
List<MapEntry<int, double>> rankProcesses(
  IMap<int, double> percentages, {
  double minPercent = 0.01,
}) {
  final entries = percentages.entries
      .where((entry) => entry.value >= minPercent)
      .toList()
    ..sort(
      (a, b) => b.value == a.value
          ? b.key.compareTo(a.key)
          : b.value.compareTo(a.value),
    );
  return entries;
}
