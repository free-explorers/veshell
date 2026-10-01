import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/amdgpu.dart';

part 'gpu_device.g.dart';

/// The GPU the card reports on, detected once at startup.
///
/// `null` when no supported card is present; the card is then omitted from the
/// panel entirely.
@Riverpod(keepAlive: true)
GpuDevice? gpuDevice(Ref ref) => detectGpuDevice();
