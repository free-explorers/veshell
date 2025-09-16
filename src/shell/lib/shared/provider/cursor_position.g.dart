// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cursor_position.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CursorPosition)
const cursorPositionProvider = CursorPositionProvider._();

final class CursorPositionProvider
    extends $NotifierProvider<CursorPosition, Offset> {
  const CursorPositionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cursorPositionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cursorPositionHash();

  @$internal
  @override
  CursorPosition create() => CursorPosition();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Offset value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Offset>(value),
    );
  }
}

String _$cursorPositionHash() => r'0f28f273a6427983af79201d37e7865b5eeb6810';

abstract class _$CursorPosition extends $Notifier<Offset> {
  Offset build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Offset, Offset>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Offset, Offset>,
              Offset,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
