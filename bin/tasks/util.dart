import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

String? importantStyle(String? m) => styleBold.wrap(blue.wrap(m));

String? commandStyle(String? m) =>
    '${backgroundBlack.wrap("\n \n > ")}${backgroundBlack.wrap(importantStyle(m))}${backgroundBlack.wrap("\n")}';

final processSet = <Process>{};

Future<int> runProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  Encoding? stdoutEncoding = systemEncoding,
  Encoding? stderrEncoding = systemEncoding,
  bool verbose = true,
}) async {
  if (verbose) {
    print("$executable ${arguments.join(" ")}\n");
  }
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
  );

  processSet.add(process);
  process.stdout.transform(utf8.decoder).listen((data) {
    if (verbose) {
      print(data);
    }
  });

  process.stderr.transform(utf8.decoder).listen((data) {
    if (verbose) {
      print(data);
    }
  });

  await process.stdin.close();
  processSet.remove(process);
  final exitCode = await process.exitCode;

  return exitCode;
}

Future<bool> isCommandAvailable(String command) async {
  final result = await Process.run('which', [command]);
  return result.exitCode == 0;
}
