// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_output.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AudioOutput)
const audioOutputProvider = AudioOutputProvider._();

final class AudioOutputProvider extends $NotifierProvider<AudioOutput, void> {
  const AudioOutputProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioOutputProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioOutputHash();

  @$internal
  @override
  AudioOutput create() => AudioOutput();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$audioOutputHash() => r'6fe14368c6a763084fe44047658a18ecf189247e';

abstract class _$AudioOutput extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
