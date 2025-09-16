// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'windows_available_for_matching.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// List of windows that are available for matching.
/// So it consider only windows in active screens in active monitors

@ProviderFor(windowsAvailableForMatching)
const windowsAvailableForMatchingProvider =
    WindowsAvailableForMatchingProvider._();

/// List of windows that are available for matching.
/// So it consider only windows in active screens in active monitors

final class WindowsAvailableForMatchingProvider
    extends $FunctionalProvider<List<WindowId>, List<WindowId>, List<WindowId>>
    with $Provider<List<WindowId>> {
  /// List of windows that are available for matching.
  /// So it consider only windows in active screens in active monitors
  const WindowsAvailableForMatchingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowsAvailableForMatchingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowsAvailableForMatchingHash();

  @$internal
  @override
  $ProviderElement<List<WindowId>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<WindowId> create(Ref ref) {
    return windowsAvailableForMatching(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<WindowId> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<WindowId>>(value),
    );
  }
}

String _$windowsAvailableForMatchingHash() =>
    r'b5fb7e5c4377a3f6fec5e966432b8d82d4579d14';
