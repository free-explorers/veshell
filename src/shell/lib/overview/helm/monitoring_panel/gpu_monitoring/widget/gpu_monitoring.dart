import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_chart.dart';
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
    final spots = ref.watch(gpuChartProvider);
    return MonitoringCard(
      icon: MdiIcons.expansionCard,
      title: 'GPU',
      badge: '${stats.load}%',
      spots: spots,
      expandedBody: Consumer(
        builder: (context, ref, child) => ProcessMetricList(
          percentages: ref.watch(processesGpuStatsProvider),
          header: GpuDetails(stats: stats),
        ),
      ),
    );
  }
}

/// Memory, temperature, power and clock details of the GPU.
class GpuDetails extends StatelessWidget {
  /// Creates the details block for [stats].
  const GpuDetails({required this.stats, super.key});

  /// The reading to display.
  final GpuStats stats;

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
        _GpuDetailRow(
          label: 'VRAM',
          value:
              '${_formatMemory(stats.vramUsedMb)} / '
              '${_formatMemory(stats.vramTotalMb)}',
        ),
        if (gttUsed != null && gttTotal != null)
          _GpuDetailRow(
            label: 'GTT',
            value: '${_formatMemory(gttUsed)} / ${_formatMemory(gttTotal)}',
          ),
        if (temperature != null)
          _GpuDetailRow(
            label: 'Temperature',
            value: '${temperature.toStringAsFixed(1)} °C',
          ),
        if (power != null)
          _GpuDetailRow(
            label: 'Power',
            value: '${power.toStringAsFixed(1)} W',
          ),
        if (coreClock != null)
          _GpuDetailRow(label: 'Core clock', value: '$coreClock MHz'),
        if (memoryClock != null)
          _GpuDetailRow(label: 'Memory clock', value: '$memoryClock MHz'),
      ],
    );
  }
}

class _GpuDetailRow extends StatelessWidget {
  const _GpuDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value),
    );
  }
}

String _formatMemory(int megabytes) {
  if (megabytes >= 1024) {
    return '${(megabytes / 1024).toStringAsFixed(1)} GB';
  }
  return '$megabytes MB';
}
