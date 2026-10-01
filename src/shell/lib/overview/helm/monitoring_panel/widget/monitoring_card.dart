import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/overview/helm/monitoring_panel/provider/process_name.dart';
import 'package:shell/shared/widget/expandable_card.dart';

/// Shared chrome for the monitoring cards.
///
/// Draws the value chart behind the header (icon, title, badge, expand toggle)
/// and, when expanded, a per-process breakdown via [expandedBody].
class MonitoringCard extends StatelessWidget {
  /// Creates a monitoring card.
  const MonitoringCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.spots,
    this.expandedBody,
    super.key,
  });

  /// Icon shown in the header.
  final IconData icon;

  /// Card title, e.g. `CPU`.
  final String title;

  /// Short value shown in the header badge, e.g. `42%`.
  final String badge;

  /// Chart samples, oldest first.
  final List<FlSpot> spots;

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
                  Positioned.fill(child: MonitoringChart(spots: spots)),
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
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
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

/// The filled line chart shared by every monitoring card.
class MonitoringChart extends StatelessWidget {
  /// Creates a chart for [spots].
  const MonitoringChart({required this.spots, super.key});

  /// Samples to draw, oldest first; an x of `-1` means "no data yet".
  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minX: spots.isEmpty ? 0 : spots.first.x,
        maxX: spots.isEmpty ? 0 : spots.last.x,
        maxY: 100,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            dotData: const FlDotData(show: false),
            barWidth: 0,
            isCurved: true,
            curveSmoothness: 0.1,
            color: Theme.of(context).colorScheme.primary,
            belowBarData: BarAreaData(
              color: Theme.of(context).colorScheme.primary.withAlpha(100),
              show: true,
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

/// Sorted per-process percentage list shared by the monitoring cards.
class ProcessMetricList extends ConsumerWidget {
  /// Creates the list for [percentages], keyed by pid.
  const ProcessMetricList({
    required this.percentages,
    this.header,
    super.key,
  });

  /// Percentage per pid.
  final IMap<int, double> percentages;

  /// Optional widget shown above the rows, scrollable together with them.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = percentages.toEntryIList().sort(
      (a, b) => b.value == a.value
          ? b.key.compareTo(a.key)
          : b.value.compareTo(a.value),
    );
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
        child: AppIconById(id: processName),
      ),
      title: Text(processName),
      trailing: Text('${process.value.toStringAsFixed(2)}%'),
    );
  }
}
