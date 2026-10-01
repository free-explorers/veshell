import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/amd.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/intel.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/nvidia.dart';

/// Reads the current telemetry of [device] with the reader for its vendor.
///
/// Each reader returns `null` rather than throwing when its interface is
/// unavailable, so an unsupported or half-readable card simply yields no data.
Future<GpuStats?> readGpuStats(GpuDevice device) {
  switch (device.vendor) {
    case GpuVendor.amd:
      return readAmdGpuStats(device);
    case GpuVendor.intel:
      return readIntelGpuStats(device);
    case GpuVendor.nvidia:
      return readNvidiaGpuStats(device);
    case GpuVendor.unknown:
      return Future.value();
  }
}
