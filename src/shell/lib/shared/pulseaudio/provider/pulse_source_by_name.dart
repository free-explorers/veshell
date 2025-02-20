import 'package:collection/collection.dart';
import 'package:pulseaudio/pulseaudio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_source_list.dart';

part 'pulse_source_by_name.g.dart';

@riverpod
class PulseSourceByName extends _$PulseSourceByName {
  @override
  PulseAudioSource? build(String sourceName) {
    final sourceList = ref.watch(pulseSourceListProvider).requireValue;
    return sourceList.firstWhereOrNull(
      (element) => element.name == sourceName,
    );
  }
}
