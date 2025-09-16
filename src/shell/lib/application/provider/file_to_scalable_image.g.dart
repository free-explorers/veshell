// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_to_scalable_image.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FileToScalableImage)
const fileToScalableImageProvider = FileToScalableImageFamily._();

final class FileToScalableImageProvider
    extends $AsyncNotifierProvider<FileToScalableImage, ScalableImage> {
  const FileToScalableImageProvider._({
    required FileToScalableImageFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fileToScalableImageProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fileToScalableImageHash();

  @override
  String toString() {
    return r'fileToScalableImageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FileToScalableImage create() => FileToScalableImage();

  @override
  bool operator ==(Object other) {
    return other is FileToScalableImageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fileToScalableImageHash() =>
    r'8486dd27a8ec762102b0039db60bf73c910de9f6';

final class FileToScalableImageFamily extends $Family
    with
        $ClassFamilyOverride<
          FileToScalableImage,
          AsyncValue<ScalableImage>,
          ScalableImage,
          FutureOr<ScalableImage>,
          String
        > {
  const FileToScalableImageFamily._()
    : super(
        retry: null,
        name: r'fileToScalableImageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  FileToScalableImageProvider call(String path) =>
      FileToScalableImageProvider._(argument: path, from: this);

  @override
  String toString() => r'fileToScalableImageProvider';
}

abstract class _$FileToScalableImage extends $AsyncNotifier<ScalableImage> {
  late final _$args = ref.$arg as String;
  String get path => _$args;

  FutureOr<ScalableImage> build(String path);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<ScalableImage>, ScalableImage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ScalableImage>, ScalableImage>,
              AsyncValue<ScalableImage>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
