// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connected_monitor_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provide list of plugged Monitors

@ProviderFor(ConnectedMonitorList)
const connectedMonitorListProvider = ConnectedMonitorListProvider._();

/// Provide list of plugged Monitors
final class ConnectedMonitorListProvider
    extends $NotifierProvider<ConnectedMonitorList, List<Monitor>> {
  /// Provide list of plugged Monitors
  const ConnectedMonitorListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectedMonitorListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectedMonitorListHash();

  @$internal
  @override
  ConnectedMonitorList create() => ConnectedMonitorList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Monitor> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Monitor>>(value),
    );
  }
}

String _$connectedMonitorListHash() =>
    r'5024afce767ed2e76540683411394b56b426fb4c';

/// Provide list of plugged Monitors

abstract class _$ConnectedMonitorList extends $Notifier<List<Monitor>> {
  List<Monitor> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<Monitor>, List<Monitor>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Monitor>, List<Monitor>>,
              List<Monitor>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
