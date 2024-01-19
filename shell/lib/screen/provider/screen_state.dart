import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_list.dart';
import 'package:shell/workspace/model/workspace.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:uuid/uuid.dart';

part 'screen_state.g.dart';

/// Screen provider
@riverpod
class ScreenState extends _$ScreenState {
  late final KeepAliveLink _keepAliveLink;
  final _uuidGenerator = const Uuid();

  @override
  Screen build(ScreenId screenId) {
    throw Exception('Screen $screenId not found');
  }

  void initialize(Screen workspace) {
    _keepAliveLink = ref.keepAlive();
    state = workspace;
  }

  WorkspaceId createNewWorkspace() {
    final workspaceId = _uuidGenerator.v4();

    ref.read(workspaceStateProvider(workspaceId).notifier).initialize(
          Workspace(
            workspaceId: workspaceId,
            tileableWindowList: <String>[].lock,
            focusedIndex: 0,
          ),
        );
    state = state.copyWith(workspaceList: state.workspaceList.add(workspaceId));
    return workspaceId;
  }
}
