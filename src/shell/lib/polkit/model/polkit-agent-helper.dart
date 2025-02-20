import 'dart:async';
import 'dart:convert';
import 'dart:io';

const helperPath = '/usr/lib/polkit-1/polkit-agent-helper-1';

enum Event {
  failed,
  request,
  showError,
  showDebug,
  complete,
}

class PolkitAgentHelper {
  PolkitAgentHelper._(this.process, this.stdout, this.stdin);
  final Process process;
  final Stream<String> stdout;
  final IOSink stdin;

  static Future<PolkitAgentHelper> start(String userName, String cookie) async {
    final process = await Process.start(
      helperPath,
      [userName],
    );

    final stdout = process.stdout.transform(utf8.decoder).asBroadcastStream();
    final stdin = process.stdin;

    stdin.writeln(cookie);
    await stdin.flush();

    return PolkitAgentHelper._(process, stdout, stdin);
  }

  Future<Event> nextEvent() async {
    final line = await stdout.firstWhere(
      (line) => line.isNotEmpty,
      orElse: () => '',
    );

    final parts = line.trim().split(' ');
    final prefix = parts[0];

    switch (prefix) {
      case 'PAM_PROMPT_ECHO_OFF':
        return Event.request;
      case 'PAM_PROMPT_ECHO_ON':
        return Event.request;
      case 'PAM_ERROR_MSG':
        return Event.showError;
      case 'PAM_TEXT_INFO':
        return Event.showDebug;
      case 'SUCCESS':
        return Event.complete;
      case 'FAILURE':
        return Event.failed;
      default:
        print('Unknown line from Polkit agent helper: $line');
        return Event.failed;
    }
  }

  Future<void> respond(String response) async {
    stdin.writeln(response);
    await stdin.flush();
  }

  Future<void> close() async {
    process.kill();
  }
}
