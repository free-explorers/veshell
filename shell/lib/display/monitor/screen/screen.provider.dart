import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/monitor/screen/screen.model.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.model.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.provider.dart';
import 'package:uuid/uuid.dart';

part 'screen.provider.g.dart';

/// Provide the current Screen to all his childrens
@Riverpod(dependencies: [])
ScreenId currentScreenId(CurrentScreenIdRef ref) {
  // This provider is instentatied in Children Scope
  throw Exception('Provider was not initialized');
}

/// ScreenList provider
@Riverpod(keepAlive: true)
class ScreenList extends _$ScreenList {
  final _uuidGenerator = const Uuid();

  @override
  ISet<ScreenId> build() {
    return <ScreenId>{}.lock;
  }

  ScreenId createNewScreen() {
    final screenId = _uuidGenerator.v4();

    ref.read(screenStateProvider(screenId).notifier)
      ..initialize(
        Screen(screenId: screenId, workspaceList: IList(), selectedIndex: 0),
      )
      ..createNewWorkspace();

    state = state.add(screenId);
    return screenId;
  }
}

/// Provide the current Focused screen
@riverpod
ScreenId? focusedScreen(FocusedScreenRef ref) {
  return ref.watch(screenListProvider).first;
}

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
