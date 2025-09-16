// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pid_to_meta_window_id.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PidToMetaWindowId)
const pidToMetaWindowIdProvider = PidToMetaWindowIdFamily._();

final class PidToMetaWindowIdProvider
    extends $NotifierProvider<PidToMetaWindowId, String?> {
  const PidToMetaWindowIdProvider._({
    required PidToMetaWindowIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'pidToMetaWindowIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pidToMetaWindowIdHash();

  @override
  String toString() {
    return r'pidToMetaWindowIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PidToMetaWindowId create() => PidToMetaWindowId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PidToMetaWindowIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pidToMetaWindowIdHash() => r'ac2785297c5447c2ebe28e1097a51b0a43e310eb';

final class PidToMetaWindowIdFamily extends $Family
    with
        $ClassFamilyOverride<
          PidToMetaWindowId,
          String?,
          String?,
          String?,
          int
        > {
  const PidToMetaWindowIdFamily._()
    : super(
        retry: null,
        name: r'pidToMetaWindowIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PidToMetaWindowIdProvider call(int pid) =>
      PidToMetaWindowIdProvider._(argument: pid, from: this);

  @override
  String toString() => r'pidToMetaWindowIdProvider';
}

abstract class _$PidToMetaWindowId extends $Notifier<String?> {
  late final _$args = ref.$arg as int;
  int get pid => _$args;

  String? build(int pid);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
