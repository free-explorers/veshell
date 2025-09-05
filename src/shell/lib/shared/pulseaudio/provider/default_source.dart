import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pulseaudio/pulseaudio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_server_info.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_source_by_name.dart';

part 'default_source.g.dart';

@riverpod
class DefaultPulseSource extends _$DefaultPulseSource {
  @override
  PulseAudioSource? build() {
    final defaultSourceName = ref.watch(
      pulseServerInfoProvider.select(
        (value) => value.requireValue.defaultSourceName,
      ),
    );
    return ref.watch(pulseSourceByNameProvider(defaultSourceName));
  }
}
