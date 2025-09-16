// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_sink.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DefaultPulseSink)
const defaultPulseSinkProvider = DefaultPulseSinkProvider._();

final class DefaultPulseSinkProvider
    extends $NotifierProvider<DefaultPulseSink, PulseAudioSink?> {
  const DefaultPulseSinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultPulseSinkProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultPulseSinkHash();

  @$internal
  @override
  DefaultPulseSink create() => DefaultPulseSink();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PulseAudioSink? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PulseAudioSink?>(value),
    );
  }
}

String _$defaultPulseSinkHash() => r'ae48441de91a7eb7e5e6c57dfaa4c2275f705eea';

abstract class _$DefaultPulseSink extends $Notifier<PulseAudioSink?> {
  PulseAudioSink? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PulseAudioSink?, PulseAudioSink?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PulseAudioSink?, PulseAudioSink?>,
              PulseAudioSink?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
