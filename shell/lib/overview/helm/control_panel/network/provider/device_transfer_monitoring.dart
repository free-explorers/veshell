import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/control_panel/network/model/device_transfer_monitoring.dart';
import 'package:shell/shared/nm/provider/nm_statistics.dart';

part 'device_transfer_monitoring.g.dart';

@riverpod
class DeviceTransferMonitoringState extends _$DeviceTransferMonitoringState {
  int prevRxBytes = 0;
  int prevTxBytes = 0;
  @override
  DeviceTransferMonitoring build(String address) {
    final initialStatistics = ref.read(nmStatisticsProvider(address));
    prevRxBytes = initialStatistics.rxBytes;
    prevTxBytes = initialStatistics.txBytes;
    // this trigger every 500ms
    ref.listen(nmStatisticsProvider(address), (_, next) {
      final prevRxBytes = this.prevRxBytes;
      final prevTxBytes = this.prevTxBytes;
      this.prevRxBytes = next.rxBytes;
      this.prevTxBytes = next.txBytes;
      state = DeviceTransferMonitoring(
        receivingBytesPerSecond: (next.rxBytes - prevRxBytes) * 2,
        transferringBytesPerSecond: (next.txBytes - prevTxBytes) * 2,
      );
    });
    return DeviceTransferMonitoring(
      receivingBytesPerSecond: 0,
      transferringBytesPerSecond: 0,
    );
  }
}
