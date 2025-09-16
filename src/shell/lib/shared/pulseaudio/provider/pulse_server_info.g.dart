// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pulse_server_info.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PulseServerInfo)
const pulseServerInfoProvider = PulseServerInfoProvider._();

final class PulseServerInfoProvider
    extends $AsyncNotifierProvider<PulseServerInfo, PulseAudioServerInfo> {
  const PulseServerInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pulseServerInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pulseServerInfoHash();

  @$internal
  @override
  PulseServerInfo create() => PulseServerInfo();
}

String _$pulseServerInfoHash() => r'9c36322c629c300ed4c60cc8f6d47c64e4447696';

abstract class _$PulseServerInfo extends $AsyncNotifier<PulseAudioServerInfo> {
  FutureOr<PulseAudioServerInfo> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<PulseAudioServerInfo>, PulseAudioServerInfo>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PulseAudioServerInfo>,
                PulseAudioServerInfo
              >,
              AsyncValue<PulseAudioServerInfo>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
