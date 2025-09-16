// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pulse_source_by_name.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PulseSourceByName)
const pulseSourceByNameProvider = PulseSourceByNameFamily._();

final class PulseSourceByNameProvider
    extends $NotifierProvider<PulseSourceByName, PulseAudioSource?> {
  const PulseSourceByNameProvider._({
    required PulseSourceByNameFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pulseSourceByNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pulseSourceByNameHash();

  @override
  String toString() {
    return r'pulseSourceByNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PulseSourceByName create() => PulseSourceByName();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PulseAudioSource? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PulseAudioSource?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PulseSourceByNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pulseSourceByNameHash() => r'd4e93e7e0bfbf523c8fba14769086f12bedec7b9';

final class PulseSourceByNameFamily extends $Family
    with
        $ClassFamilyOverride<
          PulseSourceByName,
          PulseAudioSource?,
          PulseAudioSource?,
          PulseAudioSource?,
          String
        > {
  const PulseSourceByNameFamily._()
    : super(
        retry: null,
        name: r'pulseSourceByNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PulseSourceByNameProvider call(String sourceName) =>
      PulseSourceByNameProvider._(argument: sourceName, from: this);

  @override
  String toString() => r'pulseSourceByNameProvider';
}

abstract class _$PulseSourceByName extends $Notifier<PulseAudioSource?> {
  late final _$args = ref.$arg as String;
  String get sourceName => _$args;

  PulseAudioSource? build(String sourceName);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
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
