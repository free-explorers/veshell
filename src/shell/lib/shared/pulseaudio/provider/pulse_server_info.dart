import 'package:pulseaudio/pulseaudio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';

part 'pulse_server_info.g.dart';

@Riverpod(keepAlive: true)
class PulseServerInfo extends _$PulseServerInfo {
  @override
  Future<PulseAudioServerInfo> build() async {
    final client = await ref.watch(pulseClientProvider.future);
    client.onServerInfoChanged.listen((event) {
      state = AsyncValue.data(event);
    });
    return client.getServerInfo();
  }
}
