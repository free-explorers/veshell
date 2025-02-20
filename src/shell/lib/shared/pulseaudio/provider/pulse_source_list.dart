import 'package:pulseaudio/pulseaudio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';

part 'pulse_source_list.g.dart';

@Riverpod(keepAlive: true)
class PulseSourceList extends _$PulseSourceList {
  final _sourceMapByName = <String, PulseAudioSource>{};
  final _sourceNameMapByIndex = <int, String>{};

  List<PulseAudioSource> get filteredList => _sourceMapByName.values
      .where(
        (element) => !element.name.contains('.monitor'),
      )
      .toList();
  @override
  Future<List<PulseAudioSource>> build() async {
    final client = await ref.watch(
      pulseClientProvider.future,
    );
    client.onSourceChanged.listen((source) {
      _sourceMapByName[source.name] = source;
      state = AsyncValue.data(filteredList);
    });
    client.onSourceRemoved.listen((sourceId) {
      _sourceMapByName.remove(_sourceNameMapByIndex[sourceId]);
      _sourceNameMapByIndex.remove(sourceId);
      state = AsyncValue.data(filteredList);
    });
    final list = await client.getSourceList();
    for (final source in list) {
      _sourceMapByName[source.name] = source;
      _sourceNameMapByIndex[source.index] = source.name;
    }
    return filteredList;
  }
}
