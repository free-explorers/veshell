import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Calls [onCreated] once [file] appears in its directory, which must exist.
///
/// A file can appear by being written in place (a create event) or by an
/// atomic write renaming a temporary file onto it (a move event), so both are
/// watched. Paths are compared normalized: the configuration directory may be
/// given with a trailing slash, which makes the joined path differ from the
/// one the event reports while naming the same file.
StreamSubscription<FileSystemEvent> watchFileCreation(
  File file,
  void Function() onCreated,
) {
  final target = p.normalize(file.path);
  return file.parent
      .watch(events: FileSystemEvent.create | FileSystemEvent.move)
      .listen((event) {
        final path = switch (event) {
          FileSystemMoveEvent(:final destination) => destination,
          _ => event.path,
        };
        if (path != null && p.normalize(path) == target) {
          onCreated();
        }
      });
}
