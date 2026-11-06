import 'dart:io';

import 'package:veshell_probe/src/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments);
}
