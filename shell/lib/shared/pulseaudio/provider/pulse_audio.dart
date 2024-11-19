import 'package:pulseaudio/pulseaudio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pulse_audio.g.dart';

@Riverpod(keepAlive: true)
class PulseClient extends _$PulseClient {
  @override
  Future<PulseAudioClient> build() async {
    final client = PulseAudioClient();

    await client.initialize();

    ref.onDispose(() {
      print('provider dispose');
      client.dispose();
    });

    return client;
  }

  void setDefaultSink(String name) {
    state.valueOrNull?.setDefaultSink(name);
  }

  void setDefaultSource(String name) {
    state.valueOrNull?.setDefaultSource(name);
  }

  void setSinkVolume(String name, double value) {
    state.valueOrNull?.setSinkVolume(name, value);
  }

  void setSinkMute(String name, bool value) {
    state.valueOrNull?.setSinkMute(name, value);
  }

  void setSourceVolume(String name, double value) {
    state.valueOrNull?.setSourceVolume(name, value);
  }

  void setSourceMute(String name, bool value) {
    state.valueOrNull?.setSourceMute(name, value);
  }
}
