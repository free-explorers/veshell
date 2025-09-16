// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'persistent_storage_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PersistentStorageState)
const persistentStorageStateProvider = PersistentStorageStateProvider._();

final class PersistentStorageStateProvider
    extends $AsyncNotifierProvider<PersistentStorageState, PersistentStorage> {
  const PersistentStorageStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'persistentStorageStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$persistentStorageStateHash();

  @$internal
  @override
  PersistentStorageState create() => PersistentStorageState();
}

String _$persistentStorageStateHash() =>
    r'630e9c5e28a941e9090c4ac39ff1979aff9557ca';

abstract class _$PersistentStorageState
    extends $AsyncNotifier<PersistentStorage> {
  FutureOr<PersistentStorage> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<PersistentStorage>, PersistentStorage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PersistentStorage>, PersistentStorage>,
              AsyncValue<PersistentStorage>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
