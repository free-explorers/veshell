import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shell/shared/util/logger.dart';

const helperPath = '/usr/lib/polkit-1/polkit-agent-helper-1';
const helperSocketPath = '/run/polkit/agent-helper.socket';

enum Event { failed, request, showError, showDebug, complete }

class PolkitAgentHelper {
  PolkitAgentHelper._(this.stdout, this.stdin, this._closeTransport);
  final StreamIterator<String> stdout;
  final IOSink stdin;
  final Future<void> Function() _closeTransport;

  static Future<PolkitAgentHelper> start(String userName, String cookie) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress(helperSocketPath, type: InternetAddressType.unix),
        0,
      );
    } catch (socketError) {
      polkitLog.warning(
        'Could not connect to helper socket; trying setuid helper fallback: '
        '$socketError',
      );
    }

    if (socket != null) {
      final connectedSocket = socket;
      try {
        final stdout = _lineIterator(connectedSocket);
        connectedSocket.writeln(userName);
        connectedSocket.writeln(cookie);
        await connectedSocket.flush();
        return PolkitAgentHelper._(
          stdout,
          connectedSocket,
          () async => connectedSocket.destroy(),
        );
      } catch (error, stackTrace) {
        connectedSocket.destroy();
        polkitLog.severe(
          'failed to initialize socket-activated helper',
          error,
          stackTrace,
        );
        rethrow;
      }
    }

    Process? process;
    try {
      process = await Process.start(helperPath, [userName]);
      final child = process;
      final stdout = _lineIterator(child.stdout);
      child.stdin.writeln(cookie);
      await child.stdin.flush();
      return PolkitAgentHelper._(stdout, child.stdin, () async {
        child.kill();
      });
    } catch (error, stackTrace) {
      process?.kill();
      polkitLog.severe('failed to start Polkit helper', error, stackTrace);
      rethrow;
    }
  }

  static StreamIterator<String> _lineIterator(Stream<List<int>> stream) =>
      StreamIterator<String>(
        stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
      );

  Future<Event> nextEvent() async {
    while (await stdout.moveNext()) {
      final line = stdout.current.trim();
      if (line.isEmpty) continue;

      final prefix = line.split(' ').first;

      switch (prefix) {
        case 'PAM_PROMPT_ECHO_OFF':
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
          polkitLog.warning('unknown response from agent helper: $prefix');
          return Event.failed;
      }
    }
    polkitLog.warning('agent helper closed stdout without a result');
    return Event.failed;
  }

  Future<void> respond(String response) async {
    stdin.writeln(response);
    await stdin.flush();
  }

  Future<void> close() async {
    await stdout.cancel();
    await _closeTransport();
  }
}
