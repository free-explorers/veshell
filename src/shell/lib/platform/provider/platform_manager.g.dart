// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manager for Wayland interaction
///
/// provide a stream of [PlatformEvent]
/// and a method to send [PlatformRequest]

@ProviderFor(PlatformManager)
const platformManagerProvider = PlatformManagerProvider._();

/// Manager for Wayland interaction
///
/// provide a stream of [PlatformEvent]
/// and a method to send [PlatformRequest]
final class PlatformManagerProvider
    extends $NotifierProvider<PlatformManager, Raw<Stream<PlatformEvent>>> {
  /// Manager for Wayland interaction
  ///
  /// provide a stream of [PlatformEvent]
  /// and a method to send [PlatformRequest]
  const PlatformManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformManagerHash();

  @$internal
  @override
  PlatformManager create() => PlatformManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Raw<Stream<PlatformEvent>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Raw<Stream<PlatformEvent>>>(value),
    );
  }
}

String _$platformManagerHash() => r'0dbfeb0aa435247644f509cf3aed941ff9f9cf57';

/// Manager for Wayland interaction
///
/// provide a stream of [PlatformEvent]
/// and a method to send [PlatformRequest]

abstract class _$PlatformManager extends $Notifier<Raw<Stream<PlatformEvent>>> {
  Raw<Stream<PlatformEvent>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<Raw<Stream<PlatformEvent>>, Raw<Stream<PlatformEvent>>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Raw<Stream<PlatformEvent>>,
                Raw<Stream<PlatformEvent>>
              >,
              Raw<Stream<PlatformEvent>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
