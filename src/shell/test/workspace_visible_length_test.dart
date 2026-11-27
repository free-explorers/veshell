import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

/// A workspace showing two tiles side by side, without persisted storage.
class _TwoVisibleTiles extends WorkspaceState {
  @override
  Workspace build(WorkspaceId workspaceId) => Workspace(
    workspaceId: workspaceId,
    tileableWindowList: const IListConst([]),
    selectedIndex: 0,
    visibleLength: 2,
  );
}

void main() {
  WorkspaceState notifier() {
    final container = ProviderContainer(
      overrides: [
        workspaceStateProvider('ws').overrideWith(_TwoVisibleTiles.new),
      ],
    );
    addTearDown(container.dispose);
    return container.read(workspaceStateProvider('ws').notifier);
  }

  test('the visible tiles grow and shrink one at a time', () {
    final workspace = notifier()..changeVisibleLength(1);
    expect(workspace.state.visibleLength, 3);

    workspace.changeVisibleLength(-1);
    expect(workspace.state.visibleLength, 2);
  });

  test('the visible tiles never go below one', () {
    final workspace = notifier()
      ..changeVisibleLength(-1)
      ..changeVisibleLength(-1);

    expect(workspace.state.visibleLength, 1);
  });
}
