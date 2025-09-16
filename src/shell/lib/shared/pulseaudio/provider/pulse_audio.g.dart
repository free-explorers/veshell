// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pulse_audio.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PulseClient)
const pulseClientProvider = PulseClientProvider._();

final class PulseClientProvider
    extends $AsyncNotifierProvider<PulseClient, PulseAudioClient> {
  const PulseClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulseClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulseClientHash();

  @$internal
  @override
  PulseClient create() => PulseClient();
}

String _$pulseClientHash() => r'6670a41e5ffebead6aedadd812180514356690e2';

abstract class _$PulseClient extends $AsyncNotifier<PulseAudioClient> {
  FutureOr<PulseAudioClient> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<PulseAudioClient>, PulseAudioClient>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PulseAudioClient>, PulseAudioClient>,
              AsyncValue<PulseAudioClient>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
