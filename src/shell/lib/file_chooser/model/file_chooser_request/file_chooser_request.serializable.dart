import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'file_chooser_request.serializable.freezed.dart';
part 'file_chooser_request.serializable.g.dart';

/// Which FileChooser method opened the trusted dialog: browse to open,
/// name a file to save, or pick a folder to save a set of named files.
enum FileChooserMode { open, save, saveFiles }

/// One glob/MIME pattern inside a [FileChooserFilterMessage]. `kind` is the
/// portal filter type: 0 for a glob-style pattern, 1 for a MIME type.
@freezed
sealed class FileChooserPatternMessage with _$FileChooserPatternMessage {
  /// Factory
  factory FileChooserPatternMessage({
    required int kind,
    required String pattern,
  }) = _FileChooserPatternMessage;

  /// Decode
  factory FileChooserPatternMessage.fromJson(Map<String, dynamic> json) =>
      _$FileChooserPatternMessageFromJson(json);
}

/// One user-visible filter offered by the requesting application.
@freezed
sealed class FileChooserFilterMessage with _$FileChooserFilterMessage {
  /// Factory
  factory FileChooserFilterMessage({
    required String name,
    required List<FileChooserPatternMessage> patterns,
  }) = _FileChooserFilterMessage;

  /// Decode
  factory FileChooserFilterMessage.fromJson(Map<String, dynamic> json) =>
      _$FileChooserFilterMessageFromJson(json);
}

/// A FileChooser portal request forwarded by the compositor: the trusted
/// shell resolves it with its own file explorer and answers with the chosen
/// `file://` URI(s).
@freezed
sealed class FileChooserRequestMessage
    with _$FileChooserRequestMessage
    implements PlatformMessage {
  /// Factory
  factory FileChooserRequestMessage({
    required String requestHandle,
    required int consentToken,
    required String appName,
    required String title,
    required FileChooserMode mode,
    required bool multiple,
    required bool directory,
    required List<String> files,
    required List<FileChooserFilterMessage> filters,
    String? monitorName,
    String? acceptLabel,
    String? currentFolder,
    String? currentFile,
    String? currentName,
  }) = _FileChooserRequestMessage;

  /// Decode
  factory FileChooserRequestMessage.fromJson(Map<String, dynamic> json) =>
      _$FileChooserRequestMessageFromJson(json);
}
