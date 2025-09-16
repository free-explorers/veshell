// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'process_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProcessList)
const processListProvider = ProcessListProvider._();

final class ProcessListProvider
    extends $AsyncNotifierProvider<ProcessList, ISet<int>> {
  const ProcessListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processListHash();

  @$internal
  @override
  ProcessList create() => ProcessList();
}

String _$processListHash() => r'8cea1a37ee7d3324f5c3a725fe1a02e309811498';

abstract class _$ProcessList extends $AsyncNotifier<ISet<int>> {
  FutureOr<ISet<int>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<ISet<int>>, ISet<int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ISet<int>>, ISet<int>>,
              AsyncValue<ISet<int>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
