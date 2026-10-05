import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

class _Workspace extends WorkspaceState {
  @override
  Workspace build(WorkspaceId workspaceId) => Workspace(
    workspaceId: workspaceId,
    tileableWindowList: const IListConst([
      PersistentWindowId('a'),
      PersistentWindowId('b'),
    ]),
    selectedIndex: 1,
    visibleLength: 1,
  );
}

void main() {
  test('adding an existing window to its own workspace preserves it', () async {
    final container = ProviderContainer(
      overrides: [workspaceStateProvider('ws').overrideWith(_Workspace.new)],
    );
    addTearDown(container.dispose);
    final before = container.read(workspaceStateProvider('ws'));
    await container
        .read(workspaceStateProvider('ws').notifier)
        .addWindow(const PersistentWindowId('a'));
    expect(container.read(workspaceStateProvider('ws')), before);
  });
}
