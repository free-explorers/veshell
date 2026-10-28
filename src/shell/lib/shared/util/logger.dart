import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as logging;

bool hierarchicalLoggingEnabled = true;

final focusLog = logging.Logger('Focus');
final navigationLog = logging.Logger('Navigation');
final platformLog = logging.Logger('Platform');
final persistenceLog = logging.Logger('Persistence');
final geometryLog = logging.Logger('Geometry');
final matchingLog = logging.Logger('Matching');
final notificationLog = logging.Logger('Notification');
final mprisLog = logging.Logger('Mpris');
final polkitLog = logging.Logger('Polkit');
final captureLog = logging.Logger('Capture');
final fileExplorerLog = logging.Logger('FileExplorer');
final monitoringLog = logging.Logger('Monitoring');
final flutterLog = logging.Logger('Flutter');
final iconLog = logging.Logger('Icon');

final _simpleLogger = Logger(
  printer: HybridPrinter(
    PrettyPrinter(methodCount: 0, noBoxingByDefault: true),
    info: PrettyPrinter(
      methodCount: 0,
      noBoxingByDefault: true,
      printEmojis: false,
    ),
  ),
);

final _stacktraceLogger = Logger(printer: PrettyPrinter());

/// Configures the logging system to print logs to the console.
void configureLogs() {
  logging.hierarchicalLoggingEnabled = true;

  // Persistence is normally silent, but load/migration/quarantine and flush
  // failures are exactly the events needed to diagnose a lost tile. Keep the
  // logger at INFO so the per-startup summary is visible.
  persistenceLog.level = logging.Level.INFO;

  // Per-frame surface/window layout traces log at `fine`; keep them out
  // of the default output so a moving window does not flood the log.
  geometryLog.level = logging.Level.INFO;

  logging.Logger.root.level = logging.Level.ALL; // defaults to Level.INFO
  logging.Logger.root.onRecord.listen((record) {
    final logger = record.stackTrace != null
        ? _stacktraceLogger
        : _simpleLogger;

    final loggerFunc = switch (record.level) {
      logging.Level.INFO => logger.i,
      logging.Level.WARNING => logger.w,
      logging.Level.SEVERE => logger.e,
      _ => logger.d,
    };

    loggerFunc(
      '[${record.loggerName}] ${record.message}',
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}
