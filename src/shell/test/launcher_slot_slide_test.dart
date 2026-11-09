import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/sliding_container.dart';
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

/// Like the workspace's page row: off-screen tiles are not built, so a tile
/// pulled into view after a removal is a fresh page that has no slide position
/// of its own. It starts at the index it came from.
class _PagedRow extends HookConsumerWidget {
  const _PagedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceStateProvider('ws'));
    final windowList = workspace.tileableWindowList;
    final previous = useRef<IList<PersistentWindowId>?>(null);
    final previousList = previous.value;
    previous.value = windowList;
    double? startsAt(PersistentWindowId windowId) {
      final index = previousList?.indexOf(windowId) ?? -1;
      return index < 0 ? null : index.toDouble();
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _tileWidth,
        height: 300,
        child: SlidingContainer(
          index: workspace.selectedIndex,
          children: [
            for (final (index, windowId) in windowList.indexed)
              TileDropSlot(
                key: ValueKey(windowId),
                workspaceId: 'ws',
                index: index,
                windowId: windowId,
                initialDisplayIndex: startsAt(windowId),
                child: Text(windowId.uuid),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('the next tile slides into the slot a removed tile leaves', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [workspaceStateProvider('ws').overrideWith(_Workspace.new)],
    );
    addTearDown(container.dispose);
    final workspace =
        (container.read(workspaceStateProvider('ws').notifier) as _Workspace)
          ..setWindows(['a', 'b']);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(textDirection: TextDirection.ltr, child: _row()),
      ),
    );
    expect(tester.getTopLeft(find.text('b')).dx, _tileWidth);

    workspace.setWindows(['b']);
    await tester.pump();
    // It starts where it was and moves over the slot the removed tile leaves.
    expect(tester.getTopLeft(find.text('b')).dx, _tileWidth);
    await tester.pump(const Duration(milliseconds: 120));
    final midway = tester.getTopLeft(find.text('b')).dx;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(_tileWidth));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('b')).dx, 0);
  });

  testWidgets('a tile that was not displayed still slides into a removed '
      'slot', (tester) async {
    final events = StreamController<PlatformEvent>.broadcast();
    addTearDown(events.close);
    final container = ProviderContainer(
      overrides: [
        workspaceStateProvider('ws').overrideWith(_Workspace.new),
        platformManagerProvider.overrideWithValue(events.stream),
      ],
    );
    addTearDown(container.dispose);
    final workspace =
        (container.read(workspaceStateProvider('ws').notifier) as _Workspace)
          ..setWindows(['a', 'b']);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: _PagedRow(),
        ),
      ),
    );
    // `b` sits on the next page, which is not built while `a` is shown.
    expect(find.text('b'), findsNothing);

    workspace.setWindows(['b']);
    await tester.pump();
    // The fresh page starts at the slot it came from, not in place.
    expect(tester.getTopLeft(find.text('b')).dx, _tileWidth);
    await tester.pump(const Duration(milliseconds: 120));
    final midway = tester.getTopLeft(find.text('b')).dx;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(_tileWidth));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('b')).dx, 0);
  });

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

  testWidgets('a window slot slides when its index changes, even with a '
      'single tile shown', (tester) async {
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
    // Still where it was, sliding out to make room…
    expect(tester.getTopLeft(find.text('a')).dx, 0);
    await tester.pump(const Duration(milliseconds: 120));
    final midway = tester.getTopLeft(find.text('a')).dx;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(_tileWidth));
    // …then in its own slot.
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('a')).dx, _tileWidth);
  });
}
