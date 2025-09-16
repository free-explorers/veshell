// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pulse_source_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PulseSourceList)
const pulseSourceListProvider = PulseSourceListProvider._();

final class PulseSourceListProvider
    extends $AsyncNotifierProvider<PulseSourceList, List<PulseAudioSource>> {
  const PulseSourceListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulseSourceListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulseSourceListHash();

  @$internal
  @override
  PulseSourceList create() => PulseSourceList();
}

String _$pulseSourceListHash() => r'41fc936a632114a934a1e4126ea3fd9e916c3666';

abstract class _$PulseSourceList
    extends $AsyncNotifier<List<PulseAudioSource>> {
  FutureOr<List<PulseAudioSource>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<List<PulseAudioSource>>, List<PulseAudioSource>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PulseAudioSource>>,
                List<PulseAudioSource>
              >,
              AsyncValue<List<PulseAudioSource>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
