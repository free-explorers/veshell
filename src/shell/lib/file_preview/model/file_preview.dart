import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_preview.freezed.dart';

/// What the overview's preview slot renders for the selected path.
@freezed
sealed class FilePreview with _$FilePreview {
  /// Decoded text, possibly truncated to a prefix.
  const factory FilePreview.text({
    required String content,
    required bool isTruncated,
  }) = TextFilePreview;

  /// A raster image Flutter can decode.
  const factory FilePreview.image({required String path}) = ImageFilePreview;

  /// An SVG image, rendered through `flutter_svg`.
  const factory FilePreview.svg({required String path}) = SvgFilePreview;

  /// A binary file: a hex dump of its first bytes.
  const factory FilePreview.binary({
    required String hexDump,
    required int size,
  }) = BinaryFilePreview;

  /// Nothing renderable: show size and modification time.
  const factory FilePreview.metadata({
    required String name,
    required int size,
    required DateTime modified,
  }) = MetadataFilePreview;

  /// A directory: a small summary.
  const factory FilePreview.directory({
    required String name,
    required int entryCount,
  }) = DirectoryFilePreview;

  /// The path could not be read.
  const factory FilePreview.error({required String message}) = ErrorFilePreview;
}
