// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pulse_sink_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PulseSinkList)
const pulseSinkListProvider = PulseSinkListProvider._();

final class PulseSinkListProvider
    extends $AsyncNotifierProvider<PulseSinkList, List<PulseAudioSink>> {
  const PulseSinkListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulseSinkListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulseSinkListHash();

  @$internal
  @override
  PulseSinkList create() => PulseSinkList();
}

String _$pulseSinkListHash() => r'44c5eb4be3f7f8c75e46e414a7a2968455f7edcd';

abstract class _$PulseSinkList extends $AsyncNotifier<List<PulseAudioSink>> {
  FutureOr<List<PulseAudioSink>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<List<PulseAudioSink>>, List<PulseAudioSink>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PulseAudioSink>>,
                List<PulseAudioSink>
              >,
              AsyncValue<List<PulseAudioSink>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
