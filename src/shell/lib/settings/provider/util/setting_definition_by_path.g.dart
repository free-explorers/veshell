// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting_definition_by_path.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(settingDefinitionByPath)
const settingDefinitionByPathProvider = SettingDefinitionByPathFamily._();

final class SettingDefinitionByPathProvider
    extends
        $FunctionalProvider<
          SettingDefinition?,
          SettingDefinition?,
          SettingDefinition?
        >
    with $Provider<SettingDefinition?> {
  const SettingDefinitionByPathProvider._({
    required SettingDefinitionByPathFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'settingDefinitionByPathProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$settingDefinitionByPathHash();

  @override
  String toString() {
    return r'settingDefinitionByPathProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SettingDefinition?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingDefinition? create(Ref ref) {
    final argument = this.argument as String;
    return settingDefinitionByPath(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingDefinition? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingDefinition?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SettingDefinitionByPathProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$settingDefinitionByPathHash() =>
    r'8628ead113d90e8f6b93d0a5fb7c46abd81bd618';

final class SettingDefinitionByPathFamily extends $Family
    with $FunctionalFamilyOverride<SettingDefinition?, String> {
  const SettingDefinitionByPathFamily._()
    : super(
        retry: null,
        name: r'settingDefinitionByPathProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SettingDefinitionByPathProvider call(String path) =>
      SettingDefinitionByPathProvider._(argument: path, from: this);

  @override
  String toString() => r'settingDefinitionByPathProvider';
}
