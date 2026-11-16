import 'package:pulseaudio/pulseaudio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';

part 'pulse_source_list.g.dart';

@Riverpod(keepAlive: true)
class PulseSourceList extends _$PulseSourceList {
  final _sourceMapByName = <String, PulseAudioSource>{};
  final _sourceNameMapByIndex = <int, String>{};

  List<PulseAudioSource> get filteredList => _sourceMapByName.values
      .where((element) => !element.name.contains('.monitor'))
      .toList();

  @override
  Future<List<PulseAudioSource>> build() async {
    _sourceMapByName.clear();
    _sourceNameMapByIndex.clear();
    final client = await ref.watch(pulseClientProvider.future);

    // Events received while the initial list is loading are at least as
    // recent as that list, so the list must not undo them.
    var loaded = false;
    final changedWhileLoading = <String>{};
    final removedWhileLoading = <int>{};

    final changedSubscription = client.onSourceChanged.listen((source) {
      _putSource(source);
      if (!loaded) {
        changedWhileLoading.add(source.name);
        return;
      }
      state = AsyncValue.data(filteredList);
    });
    final removedSubscription = client.onSourceRemoved.listen((index) {
      _removeSource(index);
      if (!loaded) {
        removedWhileLoading.add(index);
        return;
      }
      state = AsyncValue.data(filteredList);
    });
    ref
      ..onDispose(changedSubscription.cancel)
      ..onDispose(removedSubscription.cancel);

    final list = await client.getSourceList();
    for (final source in list) {
      if (changedWhileLoading.contains(source.name) ||
          removedWhileLoading.contains(source.index)) {
        continue;
      }
      _putSource(source);
    }
    loaded = true;
    return filteredList;
  }

  void _putSource(PulseAudioSource source) {
    final previousIndex = _sourceMapByName[source.name]?.index;
    if (previousIndex != null && previousIndex != source.index) {
      _sourceNameMapByIndex.remove(previousIndex);
    }
    _sourceMapByName[source.name] = source;
    _sourceNameMapByIndex[source.index] = source.name;
  }

  void _removeSource(int index) {
    final name = _sourceNameMapByIndex.remove(index);
    // The name may already belong to a newer source with another index.
    if (name != null && _sourceMapByName[name]?.index == index) {
      _sourceMapByName.remove(name);
    }
  }
}
