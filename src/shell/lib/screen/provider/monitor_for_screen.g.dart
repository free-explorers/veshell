// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_for_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(monitorForScreen)
const monitorForScreenProvider = MonitorForScreenFamily._();

final class MonitorForScreenProvider
    extends $FunctionalProvider<MonitorId?, MonitorId?, MonitorId?>
    with $Provider<MonitorId?> {
  const MonitorForScreenProvider._({
    required MonitorForScreenFamily super.from,
    required ScreenId super.argument,
  }) : super(
         retry: null,
         name: r'monitorForScreenProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monitorForScreenHash();

  @override
  String toString() {
    return r'monitorForScreenProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<MonitorId?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MonitorId? create(Ref ref) {
    final argument = this.argument as ScreenId;
    return monitorForScreen(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MonitorId? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MonitorId?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MonitorForScreenProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monitorForScreenHash() => r'449d5f64562c2c102fd0050d6b8d2244ef67c879';

final class MonitorForScreenFamily extends $Family
    with $FunctionalFamilyOverride<MonitorId?, ScreenId> {
  const MonitorForScreenFamily._()
    : super(
        retry: null,
        name: r'monitorForScreenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MonitorForScreenProvider call(ScreenId screenId) =>
      MonitorForScreenProvider._(argument: screenId, from: this);

  @override
  String toString() => r'monitorForScreenProvider';
}
