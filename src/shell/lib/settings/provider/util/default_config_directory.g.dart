// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_config_directory.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(defaultConfigDirectory)
const defaultConfigDirectoryProvider = DefaultConfigDirectoryProvider._();

final class DefaultConfigDirectoryProvider
    extends $FunctionalProvider<Directory, Directory, Directory>
    with $Provider<Directory> {
  const DefaultConfigDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultConfigDirectoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultConfigDirectoryHash();

  @$internal
  @override
  $ProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Directory create(Ref ref) {
    return defaultConfigDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Directory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Directory>(value),
    );
  }
}

String _$defaultConfigDirectoryHash() =>
    r'b91788205642ae1641ae5d4a7b79babeba962220';
