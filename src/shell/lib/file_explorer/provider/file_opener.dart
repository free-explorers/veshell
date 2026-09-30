import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/shared/util/logger.dart';

part 'file_opener.g.dart';

/// Starts [executable] with [arguments] and reports whether it started.
typedef ProcessStarter =
    Future<bool> Function(String executable, List<String> arguments);

/// Opens files with the user's default handler.
@Riverpod(keepAlive: true)
class FileOpener extends _$FileOpener {
  @override
  void build() {}

  /// Opens [path] with the default handler; returns whether a launcher started.
  Future<bool> openFile(DirectoryPath path) =>
      openFileWithDefaultHandler(path, startProcess: _startDetached);

  /// Starts a launcher detached from the shell and does not wait for it.
  Future<bool> _startDetached(String executable, List<String> arguments) async {
    try {
      await Process.start(
        executable,
        arguments,
        mode: ProcessStartMode.detached,
      );
      return true;
    } on ProcessException catch (error) {
      fileExplorerLog.info('$executable is unavailable: $error');
      return false;
    }
  }
}

/// Opens [path] with `xdg-open`, falling back to `gio open` when `xdg-open` is
/// not installed.
///
/// Returns whether a launcher was started; the launched handler itself is not
/// waited on, so a slow application never blocks the shell.
Future<bool> openFileWithDefaultHandler(
  DirectoryPath path, {
  required ProcessStarter startProcess,
}) async {
  if (await startProcess('xdg-open', [path.path])) {
    return true;
  }
  if (await startProcess('gio', ['open', path.path])) {
    return true;
  }
  fileExplorerLog.warning(
    'Neither xdg-open nor gio could be started to open ${path.path}',
  );
  return false;
}
