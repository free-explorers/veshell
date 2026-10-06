import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_memory_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/processes_gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/widget/monitoring_card.dart';

/// GPU load card.
class GpuMonitoringWidget extends ConsumerWidget {
  /// Creates the GPU card.
  const GpuMonitoringWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(gpuStatsStateProvider);
    final loadSpots = ref.watch(gpuChartProvider);
    final vramSpots = ref.watch(gpuMemoryChartProvider);
    final scheme = Theme.of(context).colorScheme;
    return MonitoringCard(
      icon: MdiIcons.expansionCard,
      title: context.l10n.gpu,
      badge: context.l10n.percentValue(stats.load),
      series: [
        MonitoringSeries(spots: loadSpots, color: scheme.primary, filled: true),
        if (stats.vramTotalMb > 0)
          MonitoringSeries(spots: vramSpots, color: scheme.tertiary),
      ],
      expandedBody: Consumer(
        builder: (context, ref, child) => ProcessMetricList(
          percentages: ref.watch(processesGpuStatsProvider),
          header: GpuDetails(stats: stats, vramColor: scheme.tertiary),
        ),
      ),
    );
  }
}

/// Memory, temperature, power and clock details of the GPU.
class GpuDetails extends StatelessWidget {
  /// Creates the details block for [stats].
  const GpuDetails({required this.stats, required this.vramColor, super.key});

  /// The reading to display.
  final GpuStats stats;

  /// Color of the VRAM line in the chart, reused for the VRAM value so the
  /// two are visually linked.
  final Color vramColor;

  @override
  Widget build(BuildContext context) {
    final gttUsed = stats.gttUsedMb;
    final gttTotal = stats.gttTotalMb;
    final temperature = stats.temperatureCelsius;
    final power = stats.powerWatts;
    final coreClock = stats.coreClockMhz;
    final memoryClock = stats.memoryClockMhz;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stats.vramTotalMb > 0)
          _GpuDetailRow(
            label: context.l10n.vram,
            value:
                '${_formatMemory(context, stats.vramUsedMb)} / '
                '${_formatMemory(context, stats.vramTotalMb)}',
            valueColor: vramColor,
          ),
        if (gttUsed != null && gttTotal != null)
          _GpuDetailRow(
            label: context.l10n.gtt,
            value:
                '${_formatMemory(context, gttUsed)} / ${_formatMemory(context, gttTotal)}',
          ),
        if (temperature != null)
          _GpuDetailRow(
            label: context.l10n.temperature,
            value: context.measurement(temperature, '°C', decimalDigits: 1),
          ),
        if (power != null)
          _GpuDetailRow(
            label: context.l10n.power,
            value: context.measurement(power, 'W', decimalDigits: 1),
          ),
        if (coreClock != null)
          _GpuDetailRow(
            label: context.l10n.coreClock,
            value: context.measurement(coreClock, 'MHz'),
          ),
        if (memoryClock != null)
          _GpuDetailRow(
            label: context.l10n.memoryClock,
            value: context.measurement(memoryClock, 'MHz'),
          ),
      ],
    );
  }
}

class _GpuDetailRow extends StatelessWidget {
  const _GpuDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(
        value,
        style: valueColor == null ? null : TextStyle(color: valueColor),
      ),
    );
  }
}

String _formatMemory(BuildContext context, int megabytes) {
  if (megabytes >= 1024) {
    return context.measurement(megabytes / 1024, 'GB', decimalDigits: 1);
  }
  return context.measurement(megabytes, 'MB');
}
