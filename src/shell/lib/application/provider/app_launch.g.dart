// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_launch.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppLaunch)
const appLaunchProvider = AppLaunchProvider._();

final class AppLaunchProvider extends $NotifierProvider<AppLaunch, void> {
  const AppLaunchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLaunchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLaunchHash();

  @$internal
  @override
  AppLaunch create() => AppLaunch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$appLaunchHash() => r'788e9d1c086f76b079baa67c0ac303bf1649e736';

abstract class _$AppLaunch extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
