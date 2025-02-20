import 'package:collection/collection.dart';
import 'package:pulseaudio/pulseaudio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_sink_list.dart';

part 'pulse_sink_by_name.g.dart';

@riverpod
class PulseSinkByName extends _$PulseSinkByName {
  @override
  PulseAudioSink? build(String sinkName) {
    final sinkList = ref.watch(pulseSinkListProvider).requireValue;
    return sinkList.firstWhereOrNull(
      (element) => element.name == sinkName,
    );
  }
}
