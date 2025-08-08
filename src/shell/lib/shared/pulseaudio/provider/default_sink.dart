import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pulseaudio/pulseaudio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_server_info.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_sink_by_name.dart';

part 'default_sink.g.dart';

@riverpod
class DefaultPulseSink extends _$DefaultPulseSink {
  @override
  PulseAudioSink? build() {
    final defaultSinkName = ref.watch(
      pulseServerInfoProvider.select(
        (value) => value.requireValue.defaultSinkName,
      ),
    );
    return ref.watch(pulseSinkByNameProvider(defaultSinkName));
  }
}
