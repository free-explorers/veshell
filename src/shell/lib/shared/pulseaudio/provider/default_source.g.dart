// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DefaultPulseSource)
const defaultPulseSourceProvider = DefaultPulseSourceProvider._();

final class DefaultPulseSourceProvider
    extends $NotifierProvider<DefaultPulseSource, PulseAudioSource?> {
  const DefaultPulseSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultPulseSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultPulseSourceHash();

  @$internal
  @override
  DefaultPulseSource create() => DefaultPulseSource();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PulseAudioSource? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PulseAudioSource?>(value),
    );
  }
}

String _$defaultPulseSourceHash() =>
    r'07d4dc2826bf8fcb860dc484150cdfc39a422c12';

abstract class _$DefaultPulseSource extends $Notifier<PulseAudioSource?> {
  PulseAudioSource? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PulseAudioSource?, PulseAudioSource?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PulseAudioSource?, PulseAudioSource?>,
              PulseAudioSource?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
