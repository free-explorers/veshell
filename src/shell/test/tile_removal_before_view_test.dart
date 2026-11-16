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
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

const _rowWidth = 800.0;

/// A workspace scrolled past its first windows: [selected] and [leading]
/// are what it shows.
class _Workspace extends WorkspaceState {
  _Workspace({
    required this.windows,
    required this.visible,
    required this.selected,
    required this.leading,
  });

  final List<String> windows;
  final int visible;
  final int selected;
  final int leading;

  @override
  Workspace build(WorkspaceId workspaceId) {
    ref.keepAlive();
    return Workspace(
      workspaceId: workspaceId,
      tileableWindowList: [
        for (final id in windows) PersistentWindowId(id),
      ].lock,
      selectedIndex: selected,
      visibleLength: visible,
      firstVisibleIndex: leading,
      // A fixed category: the removal does not read desktop entries.
      forcedCategory: WorkspaceCategory.Utility,
    );
  }
}

/// The workspace's page row, wired like `WorkspaceWidget`: tiles start at the
/// slot they came from, and jump with the view when it moves.
class _PagedRow extends HookConsumerWidget {
  const _PagedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceStateProvider('ws'));
    final previous = useRef<Workspace?>(null);
    final last = previous.value;
    previous.value = workspace;
    final changed =
        last != null && last.tileableWindowList != workspace.tileableWindowList;
    final viewShift = changed
        ? last.firstVisibleIndex - workspace.firstVisibleIndex
        : 0;
    double? startsAt(PersistentWindowId windowId) {
      if (!changed) return null;
      final index = last.tileableWindowList.indexOf(windowId);
      return index < 0 ? null : (index - viewShift).toDouble();
    }

    final windowList = workspace.tileableWindowList;
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _rowWidth,
        height: 300,
        child: SlidingContainer(
          index: workspace.selectedIndex,
          visible: workspace.visibleLength,
          firstVisibleIndex: workspace.firstVisibleIndex,
          onFirstVisibleIndexChanged: ref
              .read(workspaceStateProvider('ws').notifier)
              .setFirstVisibleIndex,
          children: [
            for (final (index, windowId) in windowList.indexed)
              TileDropSlot(
                key: ValueKey(windowId),
                workspaceId: 'ws',
                index: index,
                windowId: windowId,
                initialDisplayIndex: startsAt(windowId),
                viewShift: viewShift,
                child: Text(windowId.uuid),
              ),
          ],
        ),
      ),
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Workspace Function() workspace,
) async {
  final events = StreamController<PlatformEvent>.broadcast();
  addTearDown(events.close);
  final container = ProviderContainer(
    overrides: [
      workspaceStateProvider('ws').overrideWith(workspace),
      platformManagerProvider.overrideWithValue(events.stream),
      windowWorkspaceMapProvider.overrideWithValue(const IMapConst({})),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: _PagedRow(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Removes [id] and checks, frame by frame until everything settles, that
/// the tiles shown stay exactly where they were.
Future<void> _expectStill(
  WidgetTester tester,
  ProviderContainer container,
  String id,
  Map<String, double> shown,
) async {
  for (final MapEntry(key: tile, value: dx) in shown.entries) {
    expect(tester.getTopLeft(find.text(tile)).dx, dx, reason: tile);
  }
  await container
      .read(workspaceStateProvider('ws').notifier)
      .removeWindow(PersistentWindowId(id));
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
    for (final MapEntry(key: tile, value: dx) in shown.entries) {
      expect(
        tester.getTopLeft(find.text(tile)).dx,
        dx,
        reason: '$tile at frame $frame',
      );
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('removing a tile before the one shown does not move it', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      () => _Workspace(
        windows: ['a', 'b', 'c'],
        visible: 1,
        selected: 2,
        leading: 2,
      ),
    );
    await _expectStill(tester, container, 'a', {'c': 0});
    final workspace = container.read(workspaceStateProvider('ws'));
    expect(workspace.selectedIndex, 1);
    expect(workspace.firstVisibleIndex, 1);
    expect(tester.getTopLeft(find.text('c')).dx, 0);
  });

  testWidgets('removing a tile before the ones shown does not move them', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      () => _Workspace(
        windows: ['a', 'b', 'c', 'd'],
        visible: 2,
        selected: 3,
        leading: 2,
      ),
    );
    await _expectStill(tester, container, 'b', {'c': 0, 'd': _rowWidth / 2});
    final workspace = container.read(workspaceStateProvider('ws'));
    expect(workspace.selectedIndex, 2);
    expect(workspace.firstVisibleIndex, 1);
  });
}
