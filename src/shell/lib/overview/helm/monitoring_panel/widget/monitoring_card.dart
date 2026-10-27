import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/helm/monitoring_panel/model/process_ranking.dart';
import 'package:shell/overview/helm/monitoring_panel/provider/process_name.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:shell/shared/widget/expandable_card.dart';

/// One line drawn by [MonitoringChart].
class MonitoringSeries {
  /// Creates a series.
  const MonitoringSeries({
    required this.spots,
    required this.color,
    this.filled = false,
  });

  /// Samples to draw, oldest first.
  final List<FlSpot> spots;

  /// Line (and area) color.
  final Color color;

  /// Whether to fill the area under the line. Filled series are meant to be
  /// the background, with the others drawn over them.
  final bool filled;
}

/// Shared chrome for the monitoring cards.
///
/// Draws one or more value charts behind the header (icon, title, badge,
/// expand toggle) and, when expanded, a per-process breakdown via
/// [expandedBody].
class MonitoringCard extends StatelessWidget {
  /// Creates a monitoring card.
  const MonitoringCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.series,
    this.expandedBody,
    super.key,
  });

  /// Icon shown in the header.
  final IconData icon;

  /// Card title, e.g. `CPU`.
  final String title;

  /// Short value shown in the header badge, e.g. `42%`.
  final String badge;

  /// Chart lines, oldest first.
  final List<MonitoringSeries> series;

  /// Body shown while expanded, typically a [ProcessMetricList].
  final Widget? expandedBody;

  @override
  Widget build(BuildContext context) {
    return ExpandableCard(
      builder: (context, isExpanded) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: isExpanded ? 400 : double.infinity,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Positioned.fill(child: MonitoringChart(series: series)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: SizedBox(
                            height: 32,
                            width: 56,
                            child: Center(
                              child: Text(
                                badge,
                                style: Theme.of(context).textTheme.titleMedium!
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () {
                            ExpandableCard.of(context).toggle();
                          },
                          icon: Icon(
                            isExpanded
                                ? MdiIcons.chevronUp
                                : MdiIcons.chevronDown,
                          ),
                          style: IconButton.styleFrom(padding: EdgeInsets.zero),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isExpanded) const Divider(height: 2),
              if (isExpanded && expandedBody != null)
                Expanded(child: expandedBody!),
            ],
          ),
        );
      },
    );
  }
}

/// The line chart shared by every monitoring card.
///
/// Every series is drawn on the same `0..100` axis; a filled series sits under
/// the stroked ones. The viewport slides by one sample over
/// [monitoringSampleInterval] whenever a new sample arrives, so the graph
/// scrolls instead of stepping. A few samples are kept beyond each edge of the
/// visible window, so the line and area fill never stop at a chart edge.
class MonitoringChart extends StatefulWidget {
  /// Creates a chart for [series].
  const MonitoringChart({required this.series, super.key});

  /// Lines to draw, oldest first.
  final List<MonitoringSeries> series;

  @override
  State<MonitoringChart> createState() => _MonitoringChartState();
}

class _MonitoringChartState extends State<MonitoringChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: monitoringSampleInterval,
    value: 1,
  );

  bool _fillingIntoOverflow = false;
  double _fillingFrom = 0;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleAnimationStatus);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _fillingIntoOverflow) {
      setState(() {
        _fillingIntoOverflow = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant MonitoringChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLastX = _lastX(oldWidget.series);
    final newLastX = _lastX(widget.series);
    final oldFull = _hasOverflow(oldWidget.series);
    final newFull = _hasOverflow(widget.series);
    if (!oldFull && newFull) {
      // The right-aligned filling chart has to make room for the right-side
      // overflow. Move it there over one sample instead of jumping.
      _fillingFrom = (oldLastX ?? 0) - (monitoringWindowSamples - 1);
      _fillingIntoOverflow = true;
      _controller.forward(from: 0);
    } else if (oldLastX != null && newLastX != null && newLastX != oldLastX) {
      _fillingIntoOverflow = false;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstX = _firstX(widget.series);
    final lastX = _lastX(widget.series) ?? 0;
    final hasOverflow = _hasOverflow(widget.series);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // While the buffer fills, anchor the newest sample at the right edge so
        // the chart grows in from the right. Once there is overflow data, the
        // sliding window takes over; the first transition is animated from the
        // filling window to the overflow window.
        final windowStart = _fillingIntoOverflow
            ? _fillingFrom +
                  (firstX + monitoringChartOverflowSamples - _fillingFrom) *
                      _controller.value
            : hasOverflow
            ? firstX + monitoringChartOverflowSamples - 1 + _controller.value
            : lastX - (monitoringWindowSamples - 1);
        return LineChart(
          LineChartData(
            minX: windowStart,
            maxX: windowStart + monitoringWindowSamples - 1,
            maxY: 100,
            minY: 0,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              for (final line in widget.series)
                LineChartBarData(
                  spots: line.spots,
                  dotData: const FlDotData(show: false),
                  barWidth: line.filled ? 0 : 2,
                  isCurved: true,
                  curveSmoothness: 0.1,
                  color: line.color,
                  belowBarData: BarAreaData(
                    show: line.filled,
                    color: line.color.withAlpha(100),
                  ),
                ),
            ],
          ),
          duration: Duration.zero,
        );
      },
    );
  }

  bool _hasOverflow(List<MonitoringSeries> series) {
    for (final line in series) {
      if (line.spots.length >= monitoringChartBufferSamples) {
        return true;
      }
    }
    return false;
  }

  double _firstX(List<MonitoringSeries> series) {
    var first = double.infinity;
    for (final line in series) {
      for (final spot in line.spots) {
        if (spot.x < first) first = spot.x;
      }
    }
    return first == double.infinity ? 0 : first;
  }

  double? _lastX(List<MonitoringSeries> series) {
    var last = double.negativeInfinity;
    for (final line in series) {
      for (final spot in line.spots) {
        if (spot.x > last) last = spot.x;
      }
    }
    return last == double.negativeInfinity ? null : last;
  }
}

/// Sorted per-process percentage list shared by the monitoring cards.
class ProcessMetricList extends ConsumerWidget {
  /// Creates the list for [percentages], keyed by pid.
  const ProcessMetricList({required this.percentages, this.header, super.key});

  /// Percentage per pid.
  final IMap<int, double> percentages;

  /// Optional widget shown above the rows, scrollable together with them.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = rankProcesses(percentages);
    final header = this.header;
    final offset = header == null ? 0 : 1;
    return ColoredBox(
      color: Colors.black12,
      child: ListView.builder(
        itemCount: sorted.length + offset,
        itemBuilder: (context, index) {
          if (header != null && index == 0) return header;
          return _ProcessMetricRow(process: sorted[index - offset]);
        },
      ),
    );
  }
}

class _ProcessMetricRow extends ConsumerWidget {
  const _ProcessMetricRow({required this.process});

  final MapEntry<int, double> process;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processName = ref.watch(processNameProvider(process.key));
    return ListTile(
      leading: SizedBox(
        width: 24,
        height: 24,
        // Most processes have no desktop entry; a help-circle on every row is
        // noise, so show nothing when there is no matching icon.
        child: AppIconById(id: processName, fallback: const SizedBox.shrink()),
      ),
      title: Text(processName),
      trailing: Text(
        context.l10n.percentValue(num.parse(process.value.toStringAsFixed(2))),
      ),
    );
  }
}
