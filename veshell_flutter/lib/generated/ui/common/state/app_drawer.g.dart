// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/common/state/app_drawer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appDrawerFilteredDesktopEntriesHash() =>
    r'0040c16aa6809b463e5b801550753c81fe0b8922';

/// See also [appDrawerFilteredDesktopEntries].
@ProviderFor(appDrawerFilteredDesktopEntries)
final appDrawerFilteredDesktopEntriesProvider =
    FutureProvider<List<LocalizedDesktopEntry>>.internal(
  appDrawerFilteredDesktopEntries,
  name: r'appDrawerFilteredDesktopEntriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appDrawerFilteredDesktopEntriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AppDrawerFilteredDesktopEntriesRef
    = FutureProviderRef<List<LocalizedDesktopEntry>>;
String _$appDrawerFilterHash() => r'2a5e5918469d5b18336cc522a97ac02b2d3ecea2';

/// See also [AppDrawerFilter].
@ProviderFor(AppDrawerFilter)
final appDrawerFilterProvider =
    NotifierProvider<AppDrawerFilter, String>.internal(
  AppDrawerFilter.new,
  name: r'appDrawerFilterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appDrawerFilterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppDrawerFilter = Notifier<String>;
// ignore_for_file: unnecessary_raw_strings, subtype_of_sealed_class, invalid_use_of_internal_member, do_not_use_environment, prefer_const_constructors, public_member_api_docs, avoid_private_typedef_functions
