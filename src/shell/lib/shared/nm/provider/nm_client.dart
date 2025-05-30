import 'package:nm/nm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nm_client.g.dart';

@riverpod
Future<NetworkManagerClient> NmClient(
  Ref ref,
) async {
  final client = NetworkManagerClient();

  await client.connect();
  return client;
}
