// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_workspace_map.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provide a map of WindowId to WorkspaceId
/// This provider is used to find the WorkspaceId of a WindowId

@ProviderFor(WindowWorkspaceMap)
const windowWorkspaceMapProvider = WindowWorkspaceMapProvider._();

/// Provide a map of WindowId to WorkspaceId
/// This provider is used to find the WorkspaceId of a WindowId
final class WindowWorkspaceMapProvider
    extends $NotifierProvider<WindowWorkspaceMap, IMap<WindowId, WorkspaceId>> {
  /// Provide a map of WindowId to WorkspaceId
  /// This provider is used to find the WorkspaceId of a WindowId
  const WindowWorkspaceMapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowWorkspaceMapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowWorkspaceMapHash();

  @$internal
  @override
  WindowWorkspaceMap create() => WindowWorkspaceMap();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IMap<WindowId, WorkspaceId> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IMap<WindowId, WorkspaceId>>(value),
    );
  }
}

String _$windowWorkspaceMapHash() =>
    r'9ba9e54bd5b63388a26d122619a60448dd515dd0';

/// Provide a map of WindowId to WorkspaceId
/// This provider is used to find the WorkspaceId of a WindowId

abstract class _$WindowWorkspaceMap
    extends $Notifier<IMap<WindowId, WorkspaceId>> {
  IMap<WindowId, WorkspaceId> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<IMap<WindowId, WorkspaceId>, IMap<WindowId, WorkspaceId>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                IMap<WindowId, WorkspaceId>,
                IMap<WindowId, WorkspaceId>
              >,
              IMap<WindowId, WorkspaceId>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
