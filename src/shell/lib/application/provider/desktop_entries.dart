import 'dart:async';
import 'dart:io';

import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'desktop_entries.g.dart';

/// Directories that may contain installed `.desktop` files, per the XDG base
/// directory specification. Some of them may not exist.
@Riverpod(keepAlive: true)
List<Directory> applicationDirectories(Ref ref) =>
    getApplicationDirectories().map(Directory.new).toList();

/// Emits a new revision whenever the contents of an application directory may
/// have changed, so that [installedDesktopEntriesProvider] can be rebuilt.
///
/// On Linux `Directory.watch` is backed by inotify. Events are debounced
/// because installing or removing a package touches several files in a burst.
/// An application directory may only be created after the shell has started,
/// so the closest existing parent of a missing directory is watched as well.
@Riverpod(keepAlive: true)
Stream<int> desktopEntriesChanged(Ref ref) {
  final directories = ref.watch(applicationDirectoriesProvider);
  final controller = StreamController<int>();
  final watches = <String, StreamSubscription<FileSystemEvent>>{};
  Timer? debounce;
  var revision = 0;
  late void Function() syncWatches;

  void schedule() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () {
      // A directory may have appeared or disappeared; re-evaluate what to
      // watch before rebuilding the entry list.
      syncWatches();
      controller.add(revision++);
    });
  }

  void watch(String target) {
    if (watches.containsKey(target)) return;
    final directory = Directory(target);
    if (!directory.existsSync()) return;
    try {
      watches[target] = directory.watch().listen(
        (_) => schedule(),
        onError: (Object _) => watches.remove(target),
        onDone: () => watches.remove(target),
      );
    } on FileSystemException {
      // Not watchable (permissions, a race with removal, ...). The entry list
      // is still refreshed whenever another watched directory changes.
    }
  }

  syncWatches = () {
    final desired = <String>{};
    for (final directory in directories) {
      if (directory.existsSync()) {
        desired.add(directory.path);
      } else if (directory.parent.existsSync()) {
        // Watch the parent so that creating the directory is noticed.
        desired.add(directory.parent.path);
      }
    }
    for (final target in watches.keys.toList()) {
      if (!desired.contains(target)) {
        unawaited(watches.remove(target)?.cancel());
      }
    }
    desired.forEach(watch);
  };

  syncWatches();
  ref.onDispose(() {
    debounce?.cancel();
    for (final watch in watches.values) {
      unawaited(watch.cancel());
    }
    unawaited(controller.close());
  });

  return controller.stream;
}

/// The installed `.desktop` entries, keyed by desktop-file id.
///
/// The list is rescanned whenever [desktopEntriesChangedProvider] reports a
/// change, so applications installed while the shell is running show up
/// without a restart.
@Riverpod(keepAlive: true)
Future<Map<String, DesktopEntry>> installedDesktopEntries(Ref ref) {
  final directories = ref.watch(applicationDirectoriesProvider);
  // Rebuild (and therefore rescan) on every filesystem change notification.
  ref.listen(desktopEntriesChangedProvider, (_, _) => ref.invalidateSelf());
  return parseDesktopFiles(directories);
}
