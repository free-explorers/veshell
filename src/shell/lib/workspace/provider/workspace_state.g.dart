// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Workspace provider

@ProviderFor(WorkspaceState)
@JsonPersist()
const workspaceStateProvider = WorkspaceStateFamily._();

/// Workspace provider
@JsonPersist()
final class WorkspaceStateProvider
    extends $NotifierProvider<WorkspaceState, Workspace> {
  /// Workspace provider
  const WorkspaceStateProvider._({
    required WorkspaceStateFamily super.from,
    required WorkspaceId super.argument,
  }) : super(
         retry: null,
         name: r'workspaceStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceStateHash();

  @override
  String toString() {
    return r'workspaceStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorkspaceState create() => WorkspaceState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Workspace value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Workspace>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceStateHash() => r'6cb7523489d5fc8a6868007ed791e371d34016d8';

/// Workspace provider

@JsonPersist()
final class WorkspaceStateFamily extends $Family
    with
        $ClassFamilyOverride<
          WorkspaceState,
          Workspace,
          Workspace,
          Workspace,
          WorkspaceId
        > {
  const WorkspaceStateFamily._()
    : super(
        retry: null,
        name: r'workspaceStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Workspace provider

  @JsonPersist()
  WorkspaceStateProvider call(WorkspaceId workspaceId) =>
      WorkspaceStateProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'workspaceStateProvider';
}

/// Workspace provider

@JsonPersist()
abstract class _$WorkspaceStateBase extends $Notifier<Workspace> {
  late final _$args = ref.$arg as WorkspaceId;
  WorkspaceId get workspaceId => _$args;

  Workspace build(WorkspaceId workspaceId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<Workspace, Workspace>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Workspace, Workspace>,
              Workspace,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

// **************************************************************************
// JsonGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
abstract class _$WorkspaceState extends _$WorkspaceStateBase {
  /// The default key used by [persist].
  String get key {
    late final args = workspaceId;
    late final resolvedKey = 'WorkspaceState($args)';

    return resolvedKey;
  }

  /// A variant of [persist], for JSON-specific encoding.
  ///
  /// You can override [key] to customize the key used for storage.
  PersistResult persist(
    FutureOr<Storage<String, String>> storage, {
    String? key,
    String Function(Workspace state)? encode,
    Workspace Function(String encoded)? decode,
    StorageOptions options = const StorageOptions(),
  }) {
    return NotifierPersistX(this).persist<String, String>(
      storage,
      key: key ?? this.key,
      encode: encode ?? $jsonCodex.encode,
      decode:
          decode ??
          (encoded) {
            final e = $jsonCodex.decode(encoded);
            return Workspace.fromJson(e as Map<String, Object?>);
          },
      options: options,
    );
  }
}
