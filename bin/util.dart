import 'dart:convert';
import 'dart:io';

import 'package:ansicolor/ansicolor.dart';

final successColor = AnsiPen()..green(bold: true);
final importantColor = AnsiPen()..blue(bold: true);
final errorColor = AnsiPen()..red(bold: true);

Future<int> runProcess(String executable, List<String> arguments,
    {String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
    bool verbose = true}) async {
  if (verbose) {
    print("$executable ${arguments.join(" ")}\n");
  }
  final process = await Process.start(executable, arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell);

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
  final exitCode = await process.exitCode;

  return exitCode;
}
