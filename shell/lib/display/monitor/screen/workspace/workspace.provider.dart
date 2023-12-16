import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.model.dart';
import 'package:shell/manager/window/window.manager.dart';
import 'package:uuid/uuid.dart';

part 'workspace.provider.g.dart';

/// Typedef for WindowId
typedef WorkspaceId = String;

/// WorkspaceManager
@Riverpod(keepAlive: true)
class WorkspaceManager extends _$WorkspaceManager {
  final _uuidGenerator = const Uuid();

  @override
  IMap<WorkspaceId, Workspace> build() {
    return <WorkspaceId, Workspace>{
      _uuidGenerator.v4(): Workspace(
        tileableWindowList: <String>[].lock,
      ),
    }.lock;
  }

  void update(WorkspaceId workspaceId, Workspace workspace) {
    state = state.update(workspaceId, (value) => workspace);
  }
}

/// Workspace provider
@riverpod
class WorkspaceState extends _$WorkspaceState {
  late WorkspaceId _workspaceId;
  @override
  Workspace build(WorkspaceId workspaceId) {
    final workspace = ref.watch(workspaceManagerProvider).get(workspaceId);
    if (workspace == null) {
      throw Exception('Workspace $workspaceId not found');
    }
    _workspaceId = workspaceId;
    return workspace;
  }

  void addWindow(WindowId windowId) {
    ref.read(workspaceManagerProvider.notifier).update(
          _workspaceId,
          state.copyWith(
            tileableWindowList: state.tileableWindowList.add(windowId),
          ),
        );
  }
}

/// Provide the current Screen to all his childrens
@Riverpod(dependencies: [])
WorkspaceId currentWorkspaceId(CurrentWorkspaceIdRef ref) {
  // This provider is instentatied in Children Scope
  throw Exception('Provider was not initialized');
}
