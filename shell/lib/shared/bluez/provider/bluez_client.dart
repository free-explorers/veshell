import 'package:bluez/bluez.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bluez_client.g.dart';

@riverpod
Future<BlueZClient> BluezClient(BluezClientRef ref) async {
  final client = BlueZClient();

  await client.connect();
  return client;
}
