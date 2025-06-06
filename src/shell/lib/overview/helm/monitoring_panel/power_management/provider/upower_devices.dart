import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_client.dart';
import 'package:upower/upower.dart';

part 'upower_devices.g.dart';

@riverpod
Future<List<UPowerDevice>> upowerDevices(Ref ref) async {
  final upower = await ref.watch(upowerClientProvider.future);

  final addedListener = upower.deviceAdded.listen((event) {
    ref.invalidateSelf();
  });
  final removedListener = upower.deviceRemoved.listen((event) {
    ref.invalidateSelf();
  });

  ref.onDispose(() {
    addedListener.cancel();
    removedListener.cancel();
  });
  return upower.devices;
}
