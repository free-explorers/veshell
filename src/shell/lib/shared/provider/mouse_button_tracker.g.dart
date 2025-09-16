// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mouse_button_tracker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mouseButtonTracker)
const mouseButtonTrackerProvider = MouseButtonTrackerProvider._();

final class MouseButtonTrackerProvider
    extends
        $FunctionalProvider<
          MouseButtonTracker,
          MouseButtonTracker,
          MouseButtonTracker
        >
    with $Provider<MouseButtonTracker> {
  const MouseButtonTrackerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mouseButtonTrackerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mouseButtonTrackerHash();

  @$internal
  @override
  $ProviderElement<MouseButtonTracker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MouseButtonTracker create(Ref ref) {
    return mouseButtonTracker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MouseButtonTracker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MouseButtonTracker>(value),
    );
  }
}

String _$mouseButtonTrackerHash() =>
    r'ad376f71262c4bfdd4f9db443bafd59a286e50b1';
