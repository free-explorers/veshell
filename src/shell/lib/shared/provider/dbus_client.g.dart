// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dbus_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dbusClient)
const dbusClientProvider = DbusClientProvider._();

final class DbusClientProvider
    extends $FunctionalProvider<DBusClient, DBusClient, DBusClient>
    with $Provider<DBusClient> {
  const DbusClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dbusClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dbusClientHash();

  @$internal
  @override
  $ProviderElement<DBusClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DBusClient create(Ref ref) {
    return dbusClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DBusClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DBusClient>(value),
    );
  }
}

String _$dbusClientHash() => r'50fee7c6a0c704434198f5cf43c75522f48476df';
