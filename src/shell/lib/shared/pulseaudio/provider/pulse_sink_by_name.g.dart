// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pulse_sink_by_name.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PulseSinkByName)
const pulseSinkByNameProvider = PulseSinkByNameFamily._();

final class PulseSinkByNameProvider
    extends $NotifierProvider<PulseSinkByName, PulseAudioSink?> {
  const PulseSinkByNameProvider._({
    required PulseSinkByNameFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pulseSinkByNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pulseSinkByNameHash();

  @override
  String toString() {
    return r'pulseSinkByNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PulseSinkByName create() => PulseSinkByName();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PulseAudioSink? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PulseAudioSink?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PulseSinkByNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pulseSinkByNameHash() => r'e7b55fa0a3b229f8760901037132353d869ebe50';

final class PulseSinkByNameFamily extends $Family
    with
        $ClassFamilyOverride<
          PulseSinkByName,
          PulseAudioSink?,
          PulseAudioSink?,
          PulseAudioSink?,
          String
        > {
  const PulseSinkByNameFamily._()
    : super(
        retry: null,
        name: r'pulseSinkByNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PulseSinkByNameProvider call(String sinkName) =>
      PulseSinkByNameProvider._(argument: sinkName, from: this);

  @override
  String toString() => r'pulseSinkByNameProvider';
}

abstract class _$PulseSinkByName extends $Notifier<PulseAudioSink?> {
  late final _$args = ref.$arg as String;
  String get sinkName => _$args;

  PulseAudioSink? build(String sinkName);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
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
