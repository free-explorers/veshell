// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ephemeral_window_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Workspace provider

@ProviderFor(EphemeralWindowState)
const ephemeralWindowStateProvider = EphemeralWindowStateFamily._();

/// Workspace provider
final class EphemeralWindowStateProvider
    extends $NotifierProvider<EphemeralWindowState, EphemeralWindow> {
  /// Workspace provider
  const EphemeralWindowStateProvider._({
    required EphemeralWindowStateFamily super.from,
    required EphemeralWindowId super.argument,
  }) : super(
         retry: null,
         name: r'ephemeralWindowStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ephemeralWindowStateHash();

  @override
  String toString() {
    return r'ephemeralWindowStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EphemeralWindowState create() => EphemeralWindowState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EphemeralWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EphemeralWindow>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EphemeralWindowStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ephemeralWindowStateHash() =>
    r'8e7c400bee76fe7cd9018e3c23f5b946f1899350';

/// Workspace provider

final class EphemeralWindowStateFamily extends $Family
    with
        $ClassFamilyOverride<
          EphemeralWindowState,
          EphemeralWindow,
          EphemeralWindow,
          EphemeralWindow,
          EphemeralWindowId
        > {
  const EphemeralWindowStateFamily._()
    : super(
        retry: null,
        name: r'ephemeralWindowStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Workspace provider

  EphemeralWindowStateProvider call(EphemeralWindowId windowId) =>
      EphemeralWindowStateProvider._(argument: windowId, from: this);

  @override
  String toString() => r'ephemeralWindowStateProvider';
}

/// Workspace provider

abstract class _$EphemeralWindowState extends $Notifier<EphemeralWindow> {
  late final _$args = ref.$arg as EphemeralWindowId;
  EphemeralWindowId get windowId => _$args;

  EphemeralWindow build(EphemeralWindowId windowId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<EphemeralWindow, EphemeralWindow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EphemeralWindow, EphemeralWindow>,
              EphemeralWindow,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
