import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';

Future<bool> launchDesktopEntry(DesktopEntry desktopEntry) async {
  String? exec = desktopEntry.entries[DesktopEntryKey.exec.string]?.value;
  if (exec == null) {
    return false;
  }
  final bool terminal = desktopEntry.entries[DesktopEntryKey.terminal.string]?.value.getBoolean() ?? false;
  return launchApplication(command: exec, terminal: terminal);
}

Future<bool> launchApplication({required String command, bool terminal = false}) async {
  // FIXME
  command = command.replaceAll(RegExp(r'( %.?)'), '');
  debugPrint("Launching $command");

  try {
    if (terminal) {
      await Process.start('kgx', ['-e', command]);
    } else {
      await Process.start('/bin/sh', ['-c', command]);
    }
    return true;
  } on ProcessException catch (e) {
    stderr.writeln(e.toString());
    return false;
  }
}
