// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_window_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetaWindowState)
const metaWindowStateProvider = MetaWindowStateFamily._();

final class MetaWindowStateProvider
    extends $NotifierProvider<MetaWindowState, MetaWindow> {
  const MetaWindowStateProvider._({
    required MetaWindowStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'metaWindowStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$metaWindowStateHash();

  @override
  String toString() {
    return r'metaWindowStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MetaWindowState create() => MetaWindowState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MetaWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MetaWindow>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MetaWindowStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$metaWindowStateHash() => r'c4aaa50b10bfc7b34cade357a75a34262a158a86';

final class MetaWindowStateFamily extends $Family
    with
        $ClassFamilyOverride<
          MetaWindowState,
          MetaWindow,
          MetaWindow,
          MetaWindow,
          String
        > {
  const MetaWindowStateFamily._()
    : super(
        retry: null,
        name: r'metaWindowStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MetaWindowStateProvider call(String id) =>
      MetaWindowStateProvider._(argument: id, from: this);

  @override
  String toString() => r'metaWindowStateProvider';
}

abstract class _$MetaWindowState extends $Notifier<MetaWindow> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  MetaWindow build(String id);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<MetaWindow, MetaWindow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MetaWindow, MetaWindow>,
              MetaWindow,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
