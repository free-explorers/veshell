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
    _sinkMapByName.clear();
    _sinkNameMapByIndex.clear();
    final client = await ref.watch(pulseClientProvider.future);

    // Events received while the initial list is loading are at least as
    // recent as that list, so the list must not undo them.
    var loaded = false;
    final changedWhileLoading = <String>{};
    final removedWhileLoading = <int>{};

    final changedSubscription = client.onSinkChanged.listen((sink) {
      _putSink(sink);
      if (!loaded) {
        changedWhileLoading.add(sink.name);
        return;
      }
      state = AsyncValue.data(_sinkMapByName.values.toList());
    });
    final removedSubscription = client.onSinkRemoved.listen((index) {
      _removeSink(index);
      if (!loaded) {
        removedWhileLoading.add(index);
        return;
      }
      state = AsyncValue.data(_sinkMapByName.values.toList());
    });
    ref
      ..onDispose(changedSubscription.cancel)
      ..onDispose(removedSubscription.cancel);

    final list = await client.getSinkList();
    for (final sink in list) {
      if (changedWhileLoading.contains(sink.name) ||
          removedWhileLoading.contains(sink.index)) {
        continue;
      }
      _putSink(sink);
    }
    loaded = true;
    return _sinkMapByName.values.toList();
  }

  void _putSink(PulseAudioSink sink) {
    final previousIndex = _sinkMapByName[sink.name]?.index;
    if (previousIndex != null && previousIndex != sink.index) {
      _sinkNameMapByIndex.remove(previousIndex);
    }
    _sinkMapByName[sink.name] = sink;
    _sinkNameMapByIndex[sink.index] = sink.name;
  }

  void _removeSink(int index) {
    final name = _sinkNameMapByIndex.remove(index);
    // The name may already belong to a newer sink with another index.
    if (name != null && _sinkMapByName[name]?.index == index) {
      _sinkMapByName.remove(name);
    }
  }
}
