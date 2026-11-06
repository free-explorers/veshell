import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// The first port the embedder serves the VM service on; the instance on
/// Wayland socket `wayland-N` uses `12345 + N`.
const firstVmServicePort = 12345;

/// How many ports are scanned for instances.
const scannedPorts = 20;

/// A Veshell instance the probe can talk to.
class ProbeInstance {
  ProbeInstance({required this.httpUri, required this.hasProbe, this.error});

  /// The VM service's HTTP address, e.g. `http://127.0.0.1:12347/`.
  final Uri httpUri;

  /// Whether the instance serves `ext.veshell.*` (a debug build that has
  /// the probe).
  final bool hasProbe;

  /// Why the instance could not be inspected, when it could not.
  final String? error;

  Map<String, Object?> toJson() => {
    'url': '$httpUri',
    'hasProbe': hasProbe,
    if (error != null) 'error': error,
  };
}

/// A failure the probe reports to its caller as is.
class ProbeError implements Exception {
  ProbeError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The candidate addresses of running instances: [explicit] alone when given,
/// otherwise `VESHELL_VM_SERVICE_URL`, `.vscode/vmService.json` under
/// [repositoryRoot], and the scanned local ports.
Future<List<Uri>> candidateUris({
  Uri? explicit,
  Map<String, String>? environment,
  String? repositoryRoot,
}) async {
  if (explicit != null) {
    return [normalizeHttpUri(explicit)];
  }
  final candidates = <Uri>{};
  final fromEnvironment =
      (environment ?? Platform.environment)['VESHELL_VM_SERVICE_URL'];
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    candidates.add(normalizeHttpUri(Uri.parse(fromEnvironment)));
  }
  if (repositoryRoot != null) {
    final file = File(p.join(repositoryRoot, '.vscode', 'vmService.json'));
    if (file.existsSync()) {
      try {
        final uri = (jsonDecode(file.readAsStringSync()) as Map)['uri'];
        if (uri is String) {
          candidates.add(normalizeHttpUri(Uri.parse(uri)));
        }
      } on FormatException {
        // A stale or partial file: the port scan still finds the instance.
      }
    }
  }
  final open = await Future.wait([
    for (
      var port = firstVmServicePort;
      port < firstVmServicePort + scannedPorts;
      port++
    )
      isListening(port),
  ]);
  for (var index = 0; index < scannedPorts; index++) {
    if (open[index]) {
      candidates.add(
        Uri.parse('http://127.0.0.1:${firstVmServicePort + index}/'),
      );
    }
  }
  return candidates.toList();
}

/// Whether something listens on local [port].
Future<bool> isListening(int port) async {
  try {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(milliseconds: 200),
    );
    socket.destroy();
    return true;
  } on SocketException {
    return false;
  }
}

/// [uri] as the VM service's HTTP address, with a trailing slash; accepts
/// `ws://…/ws` too.
Uri normalizeHttpUri(Uri uri) {
  var path = uri.path;
  if (path.endsWith('/ws')) {
    path = path.substring(0, path.length - 2);
  }
  if (!path.endsWith('/')) {
    path = '$path/';
  }
  return uri.replace(
    scheme: uri.scheme == 'wss'
        ? 'https'
        : uri.scheme == 'ws'
        ? 'http'
        : uri.scheme,
    path: path,
  );
}

/// The VM service's websocket address for its HTTP one.
Uri webSocketUri(Uri httpUri) => httpUri.replace(
  scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
  path: '${normalizeHttpUri(httpUri).path}ws',
);

/// A connection to an instance's isolate that serves `ext.veshell.*`.
class ProbeConnection {
  ProbeConnection._(this.service, this.isolateId, this.httpUri);

  final VmService service;
  final String isolateId;
  final Uri httpUri;

  /// Connects to the instance at [httpUri]. Throws a [ProbeError] when it is
  /// not a Veshell debug build with the probe.
  static Future<ProbeConnection> open(Uri httpUri) async {
    final VmService service;
    try {
      service = await vmServiceConnectUri(
        '${webSocketUri(httpUri)}',
      ).timeout(const Duration(seconds: 5));
    } on Object catch (error) {
      throw ProbeError('Cannot reach the VM service at $httpUri: $error');
    }
    try {
      final vm = await service.getVM();
      for (final ref in vm.isolates ?? const <IsolateRef>[]) {
        final Isolate isolate;
        try {
          isolate = await service.getIsolate(ref.id!);
        } on SentinelException {
          continue; // The isolate exited while being listed.
        }
        if (isolate.extensionRPCs?.contains('ext.veshell.views') ?? false) {
          return ProbeConnection._(service, ref.id!, httpUri);
        }
      }
    } on Object catch (error) {
      await service.dispose().catchError((_) {});
      // Any failure here (an RPC error, a closed socket) only disqualifies
      // this candidate: discovery goes on with the others.
      throw ProbeError('Cannot inspect the VM at $httpUri: $error');
    }
    await service.dispose();
    throw ProbeError(
      'The instance at $httpUri has no ext.veshell extensions: it is not a '
      'debug build of Veshell with the probe (rebuild it and restart it).',
    );
  }

  /// Finds the instance to use: [explicit] when given, otherwise the only
  /// instance serving the probe among the candidates.
  static Future<ProbeConnection> discover({
    Uri? explicit,
    String? repositoryRoot,
  }) async {
    final candidates = await candidateUris(
      explicit: explicit,
      repositoryRoot: repositoryRoot,
    );
    if (candidates.isEmpty) {
      throw ProbeError(
        'No running Veshell found (no VESHELL_VM_SERVICE_URL, no '
        '.vscode/vmService.json, nothing listening on ports '
        '$firstVmServicePort-${firstVmServicePort + scannedPorts - 1}). '
        'Start a debug build, or give --url.',
      );
    }
    final failures = <String>[];
    final connections = <ProbeConnection>[];
    for (final uri in candidates) {
      try {
        connections.add(await open(uri));
      } on ProbeError catch (error) {
        failures.add(error.message);
      }
    }
    if (connections.length == 1) {
      return connections.single;
    }
    for (final connection in connections) {
      await connection.close();
    }
    if (connections.isEmpty) {
      throw ProbeError(failures.join('\n'));
    }
    throw ProbeError(
      'Several instances serve the probe; choose one with --url: '
      '${connections.map((c) => c.httpUri).join(', ')}',
    );
  }

  /// Calls `ext.veshell.<name>` (or a full extension name) and returns its
  /// result.
  Future<Object?> call(
    String name, [
    Map<String, Object?> params = const {},
  ]) async {
    final method = name.startsWith('ext.') ? name : 'ext.veshell.$name';
    try {
      final response = await service.callServiceExtension(
        method,
        isolateId: isolateId,
        args: {
          for (final MapEntry(:key, :value) in params.entries)
            if (value != null) key: '$value',
        },
      );
      final json = Map<String, Object?>.of(response.json ?? const {})
        ..remove('type');
      return json.length == 1 && json.containsKey('value')
          ? json['value']
          : json;
    } on RPCError catch (error) {
      throw ProbeError(
        '$method failed: ${error.details ?? error.message}'.split('\n').first,
      );
    }
  }

  Future<void> close() => service.dispose();
}

/// Lists the candidates and whether each serves the probe.
Future<List<ProbeInstance>> listInstances({
  Uri? explicit,
  String? repositoryRoot,
}) async {
  final instances = <ProbeInstance>[];
  for (final uri in await candidateUris(
    explicit: explicit,
    repositoryRoot: repositoryRoot,
  )) {
    try {
      final connection = await ProbeConnection.open(uri);
      await connection.close();
      instances.add(ProbeInstance(httpUri: uri, hasProbe: true));
    } on ProbeError catch (error) {
      instances.add(
        ProbeInstance(httpUri: uri, hasProbe: false, error: error.message),
      );
    }
  }
  return instances;
}
