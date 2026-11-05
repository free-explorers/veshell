import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/model/file_kind.dart';
import 'package:shell/shared/widget/shell_icon.dart';

/// A glyph for [entry]: a folder for directories, otherwise a type icon picked
/// from the file extension with a generic file glyph as fallback.
IconData iconForFileEntry(FileEntry entry) => iconForFileKind(entry.kind);

/// The glyph of one [FileKind].
IconData iconForFileKind(FileKind kind) => switch (kind) {
  FileKind.folder => MdiIcons.folder,
  FileKind.image => MdiIcons.fileImage,
  FileKind.video => MdiIcons.fileVideo,
  FileKind.audio => MdiIcons.fileMusic,
  FileKind.pdf => MdiIcons.filePdfBox,
  FileKind.document => MdiIcons.fileWord,
  FileKind.spreadsheet => MdiIcons.fileExcel,
  FileKind.table => MdiIcons.fileTable,
  FileKind.presentation => MdiIcons.filePowerpoint,
  FileKind.text => MdiIcons.fileDocument,
  FileKind.archive => MdiIcons.folderZip,
  FileKind.diskImage => MdiIcons.fileCabinet,
  FileKind.code => MdiIcons.fileCode,
  FileKind.executable => MdiIcons.application,
  FileKind.other => MdiIcons.file,
};

/// The accent of one [FileKind], so the listing can be scanned by type at a
/// glance instead of reading every name.
///
/// Folders take the theme's primary color; file kinds use a fixed hue each,
/// lightened on a dark surface and darkened on a light one so the glyph keeps
/// its contrast whatever the theme.
Color colorForFileKind(FileKind kind, ColorScheme colorScheme) {
  if (kind == FileKind.folder) {
    return colorScheme.primary;
  }
  if (kind == FileKind.other) {
    return colorScheme.onSurfaceVariant;
  }
  final hue = switch (kind) {
    FileKind.image => 290.0,
    FileKind.video => 340.0,
    FileKind.audio => 25.0,
    FileKind.pdf => 0.0,
    FileKind.document => 215.0,
    FileKind.spreadsheet || FileKind.table => 140.0,
    FileKind.presentation => 15.0,
    FileKind.text => 200.0,
    FileKind.archive => 45.0,
    FileKind.diskImage => 30.0,
    FileKind.code => 170.0,
    FileKind.executable => 260.0,
    FileKind.folder || FileKind.other => 0.0,
  };
  final isDark = colorScheme.brightness == Brightness.dark;
  return HSLColor.fromAHSL(1, hue, 0.6, isDark ? 0.72 : 0.42).toColor();
}

/// The type glyph in its kind's accent color.
class FileKindIcon extends StatelessWidget {
  const FileKindIcon({
    required this.kind,
    this.size = 24,
    this.isDimmed = false,
    super.key,
  });

  final FileKind kind;
  final double size;

  /// Hidden entries are drawn faded so the visible ones stand out.
  final bool isDimmed;

  @override
  Widget build(BuildContext context) {
    final accent = colorForFileKind(kind, Theme.of(context).colorScheme);
    return ShellIcon(
      iconForFileKind(kind),
      size: size,
      color: isDimmed ? accent.withValues(alpha: 0.5) : accent,
    );
  }
}
