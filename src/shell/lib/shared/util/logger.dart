import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as logging;

bool hierarchicalLoggingEnabled = true;

final focusLog = logging.Logger('Focus');
final persistenceLog = logging.Logger('Persistence');

final _simpleLogger = Logger(
  printer: HybridPrinter(
    PrettyPrinter(
      methodCount: 0,
      noBoxingByDefault: true,
    ),
    info: PrettyPrinter(
      methodCount: 0,
      noBoxingByDefault: true,
      printEmojis: false,
    ),
  ),
);

final _stacktraceLogger = Logger(
  printer: PrettyPrinter(),
);

/// Configures the logging system to print logs to the console.
void configureLogs() {
  logging.hierarchicalLoggingEnabled = true;

  persistenceLog.level = logging.Level.OFF;

  logging.Logger.root.level = logging.Level.ALL; // defaults to Level.INFO
  logging.Logger.root.onRecord.listen((record) {
    final logger =
        record.stackTrace != null ? _stacktraceLogger : _simpleLogger;

    final loggerFunc = switch (record.level) {
      logging.Level.INFO => logger.i,
      logging.Level.WARNING => logger.w,
      logging.Level.SEVERE => logger.e,
      _ => logger.d,
    };

    loggerFunc(
      '[${record.loggerName}] ${record.message}',
      stackTrace: record.stackTrace,
    );
  });
}
