import 'package:pulseaudio/pulseaudio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';

part 'pulse_sink_list.g.dart';

@Riverpod(keepAlive: true)
class PulseSinkList extends _$PulseSinkList {
  final _sinkMapByName = <String, PulseAudioSink>{};
  final _sinkNameMapByIndex = <int, String>{};
  @override
  Future<List<PulseAudioSink>> build() async {
    final client = await ref.watch(
      pulseClientProvider.future,
    );
    client.onSinkChanged.listen((sink) {
      _sinkMapByName[sink.name] = sink;
      state = AsyncValue.data(_sinkMapByName.values.toList());
    });
    client.onSinkRemoved.listen((sinkId) {
      _sinkMapByName.remove(_sinkNameMapByIndex[sinkId]);
      _sinkNameMapByIndex.remove(sinkId);
      state = AsyncValue.data(_sinkMapByName.values.toList());
    });
    final list = await client.getSinkList();
    for (final sink in list) {
      _sinkMapByName[sink.name] = sink;
      _sinkNameMapByIndex[sink.index] = sink.name;
    }
    return list;
  }
}
