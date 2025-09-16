// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_from_icon_query.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ImageFromIconQuery)
const imageFromIconQueryProvider = ImageFromIconQueryFamily._();

final class ImageFromIconQueryProvider
    extends $AsyncNotifierProvider<ImageFromIconQuery, Image?> {
  const ImageFromIconQueryProvider._({
    required ImageFromIconQueryFamily super.from,
    required (IconQuery, Size) super.argument,
  }) : super(
         retry: null,
         name: r'imageFromIconQueryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$imageFromIconQueryHash();

  @override
  String toString() {
    return r'imageFromIconQueryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ImageFromIconQuery create() => ImageFromIconQuery();

  @override
  bool operator ==(Object other) {
    return other is ImageFromIconQueryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$imageFromIconQueryHash() =>
    r'dff852d6e281719e1929dfb10fda38d8c30bc6e3';

final class ImageFromIconQueryFamily extends $Family
    with
        $ClassFamilyOverride<
          ImageFromIconQuery,
          AsyncValue<Image?>,
          Image?,
          FutureOr<Image?>,
          (IconQuery, Size)
        > {
  const ImageFromIconQueryFamily._()
    : super(
        retry: null,
        name: r'imageFromIconQueryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  ImageFromIconQueryProvider call(IconQuery query, Size size) =>
      ImageFromIconQueryProvider._(argument: (query, size), from: this);

  @override
  String toString() => r'imageFromIconQueryProvider';
}

abstract class _$ImageFromIconQuery extends $AsyncNotifier<Image?> {
  late final _$args = ref.$arg as (IconQuery, Size);
  IconQuery get query => _$args.$1;
  Size get size => _$args.$2;

  FutureOr<Image?> build(IconQuery query, Size size);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args.$1, _$args.$2);
    final ref = this.ref as $Ref<AsyncValue<Image?>, Image?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Image?>, Image?>,
              AsyncValue<Image?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
