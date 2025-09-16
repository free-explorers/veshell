// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_by_view_id.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(monitorByViewId)
const monitorByViewIdProvider = MonitorByViewIdFamily._();

final class MonitorByViewIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  const MonitorByViewIdProvider._({
    required MonitorByViewIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'monitorByViewIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monitorByViewIdHash();

  @override
  String toString() {
    return r'monitorByViewIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    final argument = this.argument as int;
    return monitorByViewId(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MonitorByViewIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monitorByViewIdHash() => r'003abfd77788c13e25e3c2b890add7f1319333b0';

final class MonitorByViewIdFamily extends $Family
    with $FunctionalFamilyOverride<String?, int> {
  const MonitorByViewIdFamily._()
    : super(
        retry: null,
        name: r'monitorByViewIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MonitorByViewIdProvider call(int viewId) =>
      MonitorByViewIdProvider._(argument: viewId, from: this);

  @override
  String toString() => r'monitorByViewIdProvider';
}
