import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/model/file_entry.dart';

/// A glyph for [entry]: a folder for directories, otherwise a type icon picked
/// from the file extension with a generic file glyph as fallback.
IconData iconForFileEntry(FileEntry entry) {
  if (entry.isDirectory) {
    return MdiIcons.folder;
  }
  final dotIndex = entry.name.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == entry.name.length - 1) {
    return MdiIcons.file;
  }
  final extension = entry.name.substring(dotIndex + 1).toLowerCase();
  return _iconByExtension[extension] ?? MdiIcons.file;
}

/// Extension to glyph map for the common file types. Deliberately small: the
/// list only needs a recognisable hint, not an accurate MIME database.
const Map<String, IconData> _iconByExtension = {
  'png': MdiIcons.fileImage,
  'jpg': MdiIcons.fileImage,
  'jpeg': MdiIcons.fileImage,
  'gif': MdiIcons.fileImage,
  'bmp': MdiIcons.fileImage,
  'webp': MdiIcons.fileImage,
  'svg': MdiIcons.fileImage,
  'ico': MdiIcons.fileImage,
  'tiff': MdiIcons.fileImage,
  'heic': MdiIcons.fileImage,
  'mp4': MdiIcons.fileVideo,
  'mkv': MdiIcons.fileVideo,
  'webm': MdiIcons.fileVideo,
  'avi': MdiIcons.fileVideo,
  'mov': MdiIcons.fileVideo,
  'm4v': MdiIcons.fileVideo,
  'wmv': MdiIcons.fileVideo,
  'mp3': MdiIcons.fileMusic,
  'flac': MdiIcons.fileMusic,
  'wav': MdiIcons.fileMusic,
  'ogg': MdiIcons.fileMusic,
  'oga': MdiIcons.fileMusic,
  'm4a': MdiIcons.fileMusic,
  'aac': MdiIcons.fileMusic,
  'opus': MdiIcons.fileMusic,
  'pdf': MdiIcons.filePdfBox,
  'doc': MdiIcons.fileWord,
  'docx': MdiIcons.fileWord,
  'odt': MdiIcons.fileWord,
  'xls': MdiIcons.fileExcel,
  'xlsx': MdiIcons.fileExcel,
  'ods': MdiIcons.fileExcel,
  'csv': MdiIcons.fileTable,
  'ppt': MdiIcons.filePowerpoint,
  'pptx': MdiIcons.filePowerpoint,
  'odp': MdiIcons.filePowerpoint,
  'txt': MdiIcons.fileDocument,
  'md': MdiIcons.fileDocument,
  'rtf': MdiIcons.fileDocument,
  'zip': MdiIcons.folderZip,
  'tar': MdiIcons.folderZip,
  'gz': MdiIcons.folderZip,
  'tgz': MdiIcons.folderZip,
  'xz': MdiIcons.folderZip,
  'bz2': MdiIcons.folderZip,
  '7z': MdiIcons.folderZip,
  'rar': MdiIcons.folderZip,
  'zst': MdiIcons.folderZip,
  'iso': MdiIcons.fileCabinet,
  'img': MdiIcons.fileCabinet,
  'dart': MdiIcons.fileCode,
  'js': MdiIcons.fileCode,
  'ts': MdiIcons.fileCode,
  'jsx': MdiIcons.fileCode,
  'tsx': MdiIcons.fileCode,
  'py': MdiIcons.fileCode,
  'rs': MdiIcons.fileCode,
  'go': MdiIcons.fileCode,
  'c': MdiIcons.fileCode,
  'h': MdiIcons.fileCode,
  'cpp': MdiIcons.fileCode,
  'hpp': MdiIcons.fileCode,
  'java': MdiIcons.fileCode,
  'kt': MdiIcons.fileCode,
  'swift': MdiIcons.fileCode,
  'rb': MdiIcons.fileCode,
  'php': MdiIcons.fileCode,
  'sh': MdiIcons.fileCode,
  'bash': MdiIcons.fileCode,
  'zsh': MdiIcons.fileCode,
  'json': MdiIcons.fileCode,
  'yaml': MdiIcons.fileCode,
  'yml': MdiIcons.fileCode,
  'toml': MdiIcons.fileCode,
  'xml': MdiIcons.fileCode,
  'html': MdiIcons.fileCode,
  'css': MdiIcons.fileCode,
  'sql': MdiIcons.fileCode,
  'desktop': MdiIcons.application,
  'appimage': MdiIcons.application,
  'exe': MdiIcons.application,
  'bin': MdiIcons.application,
};
