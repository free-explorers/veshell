import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/screen/model/screen.dart';
import 'package:uuid/uuid.dart';

part 'screen_list.g.dart';

const initialScreenLength = 2;

/// ScreenList provider
@Riverpod(keepAlive: true)
class ScreenList extends _$ScreenList {
  final _uuidGenerator = const Uuid();

  @override
  ISet<ScreenId> build(MonitorId monitorName) {
    return <ScreenId>{
      for (var i = 0; i < initialScreenLength; i++) _uuidGenerator.v4(),
    }.lock;
  }

  ScreenId createNewScreen() {
    final screenId = _uuidGenerator.v4();
    state = state.add(screenId);
    return screenId;
  }
}
