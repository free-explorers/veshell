import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as Logging;

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
  Logging.Logger.root.level = Logging.Level.ALL; // defaults to Level.INFO
  Logging.Logger.root.onRecord.listen((record) {
    final logger =
        record.stackTrace != null ? _stacktraceLogger : _simpleLogger;

    final loggerFunc = switch (record.level) {
      Logging.Level.INFO => logger.i,
      Logging.Level.WARNING => logger.w,
      Logging.Level.SEVERE => logger.e,
      _ => logger.d,
    };

    loggerFunc(
      '[${record.loggerName}] ${record.message}',
      stackTrace: record.stackTrace,
    );
  });
}
