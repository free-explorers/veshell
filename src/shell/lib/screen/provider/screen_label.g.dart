// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_label.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(screenLabel)
const screenLabelProvider = ScreenLabelFamily._();

final class ScreenLabelProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  const ScreenLabelProvider._({
    required ScreenLabelFamily super.from,
    required ScreenId super.argument,
  }) : super(
         retry: null,
         name: r'screenLabelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$screenLabelHash();

  @override
  String toString() {
    return r'screenLabelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as ScreenId;
    return screenLabel(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ScreenLabelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$screenLabelHash() => r'7a2c731bd37d1273d8918a5e1192f2aa302d4da5';

final class ScreenLabelFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, ScreenId> {
  const ScreenLabelFamily._()
    : super(
        retry: null,
        name: r'screenLabelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ScreenLabelProvider call(ScreenId screenId) =>
      ScreenLabelProvider._(argument: screenId, from: this);

  @override
  String toString() => r'screenLabelProvider';
}
