import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:veshell_probe/src/connection.dart';

/// A client of the embedder's control socket (`VESHELL_PROBE_SOCKET`, debug
/// builds): the composited output and input through the compositor.
class CompositorControl {
  CompositorControl(this.socketPath);

  final String socketPath;

  /// Sends one request and returns its reply.
  Future<Map<String, Object?>> request(Map<String, Object?> request) async {
    final Socket socket;
    try {
      socket = await Socket.connect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 5),
      );
    } on SocketException catch (error) {
      throw ProbeError(
        'Cannot reach the compositor control socket $socketPath: $error',
      );
    }
    try {
      socket.write('${jsonEncode(request)}\n');
      await socket.flush();
      final line = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 45));
      final reply = jsonDecode(line) as Map<String, Object?>;
      if (reply['error'] case final String error) {
        throw ProbeError('The compositor refused ${request['op']}: $error');
      }
      return reply;
    } on TimeoutException {
      throw ProbeError('The compositor did not answer ${request['op']}');
    } finally {
      socket.destroy();
    }
  }

  /// The outputs: name, logical geometry, scale, pixel size.
  Future<List<Map<String, Object?>>> outputs() async =>
      ((await request({'op': 'outputs'}))['outputs']! as List)
          .cast<Map<String, Object?>>();

  /// Writes the composited output (application windows included) to [path].
  Future<Map<String, Object?>> captureOutput(String path, {String? output}) =>
      request({'op': 'capture_output', 'path': path, 'output': output});

  /// Injects [events] (motion, button, axis, key) as input devices do.
  Future<Map<String, Object?>> inject(List<Map<String, Object?>> events) =>
      request({'op': 'inject', 'events': events});
}

/// The key events of pressing [chord] (`Super+Q`): each key down in order,
/// then up in reverse.
List<Map<String, Object?>> chordEvents(String chord) {
  final keys = [
    for (final key in chord.split('+'))
      if (key.trim().isNotEmpty) key.trim().toLowerCase().replaceAll(' ', ''),
  ];
  if (keys.isEmpty) {
    throw ProbeError('Give a key, such as Enter or Super+Q');
  }
  return [
    for (final key in keys) {'type': 'key', 'key': key, 'state': 'pressed'},
    for (final key in keys.reversed)
      {'type': 'key', 'key': key, 'state': 'released'},
  ];
}

/// The key events typing [text]: letters, digits and spaces (shift for
/// capitals). Anything else is typed through Flutter instead.
List<Map<String, Object?>> typingEvents(String text) {
  final events = <Map<String, Object?>>[];
  for (final character in text.split('')) {
    final lower = character.toLowerCase();
    final isLetter = RegExp('[a-z]').hasMatch(lower);
    if (!isLetter && !RegExp('[0-9 ]').hasMatch(character)) {
      throw ProbeError(
        'Cannot type "$character" through the compositor (letters, digits and '
        'spaces only): type it with via=flutter',
      );
    }
    final key = character == ' ' ? 'space' : lower;
    events.addAll(
      chordEvents(isLetter && character != lower ? 'shift+$key' : key),
    );
  }
  return events;
}

/// The events of a left click at [x], [y] (compositor coordinates).
List<Map<String, Object?>> clickEvents(double x, double y) => [
  {'type': 'motion', 'x': x, 'y': y},
  {'type': 'button', 'button': 'left', 'state': 'pressed'},
  {'type': 'button', 'button': 'left', 'state': 'released'},
];
