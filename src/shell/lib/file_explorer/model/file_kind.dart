/// The broad type of a file explorer entry, derived from its extension.
///
/// It drives the row's glyph and accent, the "type" sort order and the MIME
/// approximation of the portal chooser's filters. Deliberately coarse: a
/// recognisable hint, not an accurate MIME database.
enum FileKind {
  folder,
  image,
  video,
  audio,
  pdf,
  document,
  spreadsheet,
  table,
  presentation,
  text,
  archive,
  diskImage,
  code,
  executable,
  other,
}

/// The lowercase extension of [name] without the dot, or `''` when it has
/// none (a dotfile such as `.bashrc` has no extension).
String fileExtension(String name) {
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == name.length - 1) {
    return '';
  }
  return name.substring(dotIndex + 1).toLowerCase();
}

/// The [FileKind] of a file called [name] (never [FileKind.folder]).
FileKind fileKindForName(String name) =>
    _kindByExtension[fileExtension(name)] ?? FileKind.other;

/// The extensions of one [FileKind], for matching a MIME family such as
/// `image/*` against file names.
Iterable<String> extensionsForFileKind(FileKind kind) => _kindByExtension
    .entries
    .where((entry) => entry.value == kind)
    .map((entry) => entry.key);

const Map<String, FileKind> _kindByExtension = {
  'png': FileKind.image,
  'jpg': FileKind.image,
  'jpeg': FileKind.image,
  'gif': FileKind.image,
  'bmp': FileKind.image,
  'webp': FileKind.image,
  'svg': FileKind.image,
  'ico': FileKind.image,
  'tif': FileKind.image,
  'tiff': FileKind.image,
  'heic': FileKind.image,
  'avif': FileKind.image,
  'mp4': FileKind.video,
  'mkv': FileKind.video,
  'webm': FileKind.video,
  'avi': FileKind.video,
  'mov': FileKind.video,
  'm4v': FileKind.video,
  'wmv': FileKind.video,
  'mp3': FileKind.audio,
  'flac': FileKind.audio,
  'wav': FileKind.audio,
  'ogg': FileKind.audio,
  'oga': FileKind.audio,
  'm4a': FileKind.audio,
  'aac': FileKind.audio,
  'opus': FileKind.audio,
  'pdf': FileKind.pdf,
  'doc': FileKind.document,
  'docx': FileKind.document,
  'odt': FileKind.document,
  'xls': FileKind.spreadsheet,
  'xlsx': FileKind.spreadsheet,
  'ods': FileKind.spreadsheet,
  'csv': FileKind.table,
  'ppt': FileKind.presentation,
  'pptx': FileKind.presentation,
  'odp': FileKind.presentation,
  'txt': FileKind.text,
  'md': FileKind.text,
  'rtf': FileKind.text,
  'log': FileKind.text,
  'zip': FileKind.archive,
  'tar': FileKind.archive,
  'gz': FileKind.archive,
  'tgz': FileKind.archive,
  'xz': FileKind.archive,
  'bz2': FileKind.archive,
  '7z': FileKind.archive,
  'rar': FileKind.archive,
  'zst': FileKind.archive,
  'iso': FileKind.diskImage,
  'img': FileKind.diskImage,
  'dart': FileKind.code,
  'js': FileKind.code,
  'ts': FileKind.code,
  'jsx': FileKind.code,
  'tsx': FileKind.code,
  'py': FileKind.code,
  'rs': FileKind.code,
  'go': FileKind.code,
  'c': FileKind.code,
  'h': FileKind.code,
  'cpp': FileKind.code,
  'hpp': FileKind.code,
  'java': FileKind.code,
  'kt': FileKind.code,
  'swift': FileKind.code,
  'rb': FileKind.code,
  'php': FileKind.code,
  'sh': FileKind.code,
  'bash': FileKind.code,
  'zsh': FileKind.code,
  'json': FileKind.code,
  'yaml': FileKind.code,
  'yml': FileKind.code,
  'toml': FileKind.code,
  'xml': FileKind.code,
  'html': FileKind.code,
  'css': FileKind.code,
  'sql': FileKind.code,
  'desktop': FileKind.executable,
  'appimage': FileKind.executable,
  'exe': FileKind.executable,
  'bin': FileKind.executable,
};
