import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matching_logs.g.dart';

final _log = Logger('MatchingEngine');

@Riverpod(keepAlive: true)
class MatchingLogs extends _$MatchingLogs {
  @override
  List<String> build() {
    return [];
  }

  void print(String message) {
    state = [...state, message];
    _log.info(message);
  }
}
