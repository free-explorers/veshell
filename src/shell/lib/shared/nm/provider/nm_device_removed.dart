import 'package:nm/nm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/nm/provider/nm_client.dart';

part 'nm_device_removed.g.dart';

@riverpod
Stream<NetworkManagerDevice> NmDeviceRemoved(Ref ref) async* {
  final client = await ref.watch(nmClientProvider.future);
  yield* client.deviceRemoved;
}
