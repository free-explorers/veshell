import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/tile_grab/widget/tile_drop_slot.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

const _tileWidth = 400.0;

class _Workspace extends WorkspaceState {
  @override
  Workspace build(WorkspaceId workspaceId) {
    ref.keepAlive();
    return Workspace(
      workspaceId: workspaceId,
      tileableWindowList: const IListConst([]),
      selectedIndex: 0,
      visibleLength: 1,
    );
  }

  void setWindows(List<String> ids) => state = state.copyWith(
    tileableWindowList: [for (final id in ids) PersistentWindowId(id)].lock,
  );
}

/// A row of the workspace's slots, one shown, then the launcher's — keyed
/// like the workspace's, so a slot keeps its state when its index changes.
Widget _row() => Consumer(
  builder: (context, ref, _) {
    final windows = ref.watch(
      workspaceStateProvider('ws').select((w) => w.tileableWindowList),
    );
    Widget slot(int index, PersistentWindowId? windowId, String label) =>
        SizedBox(
          key: ValueKey(windowId ?? 'launcher'),
          width: _tileWidth,
          child: TileDropSlot(
            workspaceId: 'ws',
            index: index,
            windowId: windowId,
            child: Text(label),
          ),
        );
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _tileWidth,
        height: 300,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, windowId) in windows.indexed)
                slot(index, windowId, windowId.uuid),
              slot(windows.length, null, 'launcher'),
            ],
          ),
        ),
      ),
    );
  },
);

void main() {
  testWidgets('a tile inserted in the launcher place slides the launcher '
      'aside, even with a single tile shown', (tester) async {
    final container = ProviderContainer(
      overrides: [workspaceStateProvider('ws').overrideWith(_Workspace.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(textDirection: TextDirection.ltr, child: _row()),
      ),
    );
    expect(tester.getTopLeft(find.text('launcher')).dx, 0);

    (container.read(workspaceStateProvider('ws').notifier) as _Workspace)
        .setWindows(['new']);
    await tester.pump();
    // Still where it was, under the new tile…
    expect(tester.getTopLeft(find.text('launcher')).dx, 0);
    await tester.pump(const Duration(milliseconds: 120));
    final midway = tester.getTopLeft(find.text('launcher')).dx;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(_tileWidth));
    // …then in its own slot.
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('launcher')).dx, _tileWidth);
  });

  testWidgets('a window slot keeps jumping with a single tile shown', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [workspaceStateProvider('ws').overrideWith(_Workspace.new)],
    );
    addTearDown(container.dispose);
    (container.read(workspaceStateProvider('ws').notifier) as _Workspace)
        .setWindows(['a']);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(textDirection: TextDirection.ltr, child: _row()),
      ),
    );

    (container.read(workspaceStateProvider('ws').notifier) as _Workspace)
        .setWindows(['new', 'a']);
    await tester.pump();
    expect(tester.getTopLeft(find.text('a')).dx, _tileWidth);
  });
}
