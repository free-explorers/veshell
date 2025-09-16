// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'json_value_by_path.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(jsonValueByPath)
const jsonValueByPathProvider = JsonValueByPathFamily._();

final class JsonValueByPathProvider
    extends $FunctionalProvider<dynamic, dynamic, dynamic>
    with $Provider<dynamic> {
  const JsonValueByPathProvider._({
    required JsonValueByPathFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'jsonValueByPathProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$jsonValueByPathHash();

  @override
  String toString() {
    return r'jsonValueByPathProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<dynamic> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  dynamic create(Ref ref) {
    final argument = this.argument as String;
    return jsonValueByPath(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(dynamic value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<dynamic>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is JsonValueByPathProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$jsonValueByPathHash() => r'2fcee9255da1f3bca999c9fc163ffe9a8cdba9c5';

final class JsonValueByPathFamily extends $Family
    with $FunctionalFamilyOverride<dynamic, String> {
  const JsonValueByPathFamily._()
    : super(
        retry: null,
        name: r'jsonValueByPathProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  JsonValueByPathProvider call(String path) =>
      JsonValueByPathProvider._(argument: path, from: this);

  @override
  String toString() => r'jsonValueByPathProvider';
}
