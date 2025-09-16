// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'available_screen_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(availableScreenList)
const availableScreenListProvider = AvailableScreenListProvider._();

final class AvailableScreenListProvider
    extends $FunctionalProvider<ISet<ScreenId>, ISet<ScreenId>, ISet<ScreenId>>
    with $Provider<ISet<ScreenId>> {
  const AvailableScreenListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'availableScreenListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$availableScreenListHash();

  @$internal
  @override
  $ProviderElement<ISet<ScreenId>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ISet<ScreenId> create(Ref ref) {
    return availableScreenList(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISet<ScreenId> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISet<ScreenId>>(value),
    );
  }
}

String _$availableScreenListHash() =>
    r'4d3a8c42fbf5f9dade9fc800b1210f6d641bc207';
