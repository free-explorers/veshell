import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:upower/upower.dart';

part 'upower_client.g.dart';

@riverpod
class UpowerClient extends _$UpowerClient {
  @override
  Future<UPowerClient> build() async {
    final client = UPowerClient();
    await client.connect();
    ref.onDispose(client.close);
    return client;
  }
}
