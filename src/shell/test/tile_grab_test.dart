import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/widget/multi_view_drag.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/tile_grab/model/tile_drop.dart';
import 'package:shell/tile_grab/model/tile_grab.dart';
import 'package:shell/tile_grab/model/tile_grab_marker.dart';
import 'package:shell/tile_grab/provider/tile_grab_controller.dart';
import 'package:shell/tile_grab/widget/tile_drop_slot.dart';
import 'package:shell/tile_grab/widget/tile_grab_preview.dart';
import 'package:shell/tile_grab/widget/tile_grab_region.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/widget/window_placeholder.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/current_workspace_id.dart';

IList<PersistentWindowId> _windows(List<String> ids) =>
    ids.map(PersistentWindowId.new).toIList();

List<String> _ids(IList<PersistentWindowId> windows) =>
    windows.map((w) => w.uuid).toList();

/// A second independently laid-out Flutter view using the test engine's
/// backing view for rendering. Hit tests are still keyed by its own view id.
class _SecondView extends TestFlutterView {
  _SecondView(WidgetTester tester)
    : super(
        view: tester.view,
        platformDispatcher: tester.platformDispatcher,
        display: tester.view.display,
      );

  @override
  int get viewId => 42;
}

/// A window that is not displayed: the held tile shows its placeholder.
class _FakeWindowState extends PersistentWindowState {
  @override
  PersistentWindow build(PersistentWindowId windowId) => PersistentWindow(
    windowId: windowId,
    properties: WindowProperties(appId: 'app', title: windowId.uuid),
  );
}

class _NoDesktopEntry extends LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => null;
}

class _FakeScreenState extends ScreenState {
  _FakeScreenState(this._screen);
  final Screen _screen;

  @override
  Screen build(ScreenId screenId) => _screen;
}

/// Mutates the order synchronously and records transfers instead of running
/// the asynchronous category lookup of `insertWindow`.
class _FakeWorkspaceState extends WorkspaceState {
  _FakeWorkspaceState(this._workspace, this.inserted);
  final Workspace _workspace;
  final List<(WorkspaceId, PersistentWindowId, int)> inserted;

  @override
  Workspace build(WorkspaceId workspaceId) {
    // Like the real notifier, so changes survive while nothing listens.
    ref.keepAlive();
    return _workspace;
  }

  @override
  Future<void> insertWindow(
    PersistentWindowId windowId,
    int index, {
    bool selectWindow = false,
  }) async {
    inserted.add((workspaceId, windowId, index));
  }
}

// Real tile proportions: the carried placeholder is the real one, laid out at
// the tile's size.
const _tileWidth = 1280.0;
const _tileHeight = 800.0;

/// Each view holds a row of three tiles.
const _viewSize = Size(_tileWidth * 3, _tileHeight);
const _secondViewOrigin = Offset(_tileWidth * 3, 0);

/// One screen with one workspace laid out as a row of grabbable tiles.
Widget _screen({
  required ScreenId screenId,
  required WorkspaceId workspaceId,
  required List<String> windows,
  required Offset origin,
}) => MaterialApp(
  localizationsDelegates: shellLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: ShellDragView(
    origin: origin,
    child: Stack(
      fit: StackFit.expand,
      children: [
        _workspaceRow(
          screenId: screenId,
          workspaceId: workspaceId,
          windows: windows,
        ),
        TileGrabPreview(origin: origin),
      ],
    ),
  ),
);

Widget _workspaceRow({
  required ScreenId screenId,
  required WorkspaceId workspaceId,
  required List<String> windows,
}) => CurrentScreenId(
  screenId: screenId,
  child: MetaData(
    metaData: TileGrabScreenMarker(screenId),
    behavior: HitTestBehavior.translucent,
    child: CurrentWorkspaceId(
      workspaceId: workspaceId,
      child: Align(
        alignment: Alignment.topLeft,
        // Like the workspace: slots follow the committed order, keyed by
        // window so a reordered tile keeps where it is shown, and the row's
        // viewport spans the visible slots only.
        child: Consumer(
          builder: (context, ref, _) {
            final (windowList, visible) = ref.watch(
              workspaceStateProvider(
                workspaceId,
              ).select((w) => (w.tileableWindowList, w.visibleLength)),
            );
            return MetaData(
              metaData: TileRowMarker(
                workspaceId: workspaceId,
                visible: visible,
                scrollOffset: () => 0,
              ),
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: visible * _tileWidth,
                height: _tileHeight,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxWidth: double.infinity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (index, windowId) in windowList.indexed)
                          SizedBox(
                            key: ValueKey(windowId),
                            width: _tileWidth,
                            height: _tileHeight,
                            child: TileDropSlot(
                              workspaceId: workspaceId,
                              index: index,
                              windowId: windowId,
                              child: TileGrabRegion(
                                windowId: windowId,
                                child: ColoredBox(
                                  color: Colors.blue,
                                  child: Center(child: Text(windowId.uuid)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
);

/// A point inside the slot [index] of a row, [dx] of the way across it.
Offset _slot(int index, {double dx = 0.25}) =>
    Offset((index + dx) * _tileWidth, _tileHeight / 2);

/// Lets a released tile fly to where it lands and the drop commit: the flight
/// starts on the next frame.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(tileGrabSettleDuration + const Duration(milliseconds: 50));
  // The commit lays the tiles out for a frame before the copy hands over.
  await tester.pump();
}

void main() {
  group('planTileDrop', () {
    final windows = _windows(['a', 'b', 'c']);

    TileDropPlan plan(TileDropTarget target, {WorkspaceId source = 'ws'}) =>
        planTileDrop(
          windowId: const PersistentWindowId('a'),
          sourceWorkspaceId: source,
          target: target,
          destinationWindowList: windows,
        );

    test('moves the tile to the target index, shifting the others', () {
      final result = plan(
        const TileDropTarget.slot(workspaceId: 'ws', index: 1),
      );
      expect(result, isA<TileDropReorder>());
      expect(_ids((result as TileDropReorder).windowList), ['b', 'a', 'c']);
    });

    test('moves to the end when dropped on the launcher slot', () {
      final result = plan(
        const TileDropTarget.slot(workspaceId: 'ws', index: 3),
      );
      expect(_ids((result as TileDropReorder).windowList), ['b', 'c', 'a']);
    });

    test('dropping on its own slot is a no-op', () {
      expect(
        plan(const TileDropTarget.slot(workspaceId: 'ws', index: 0)),
        isA<TileDropNoop>(),
      );
    });

    test('dropping on its own workspace button is a no-op', () {
      expect(
        plan(const TileDropTarget.workspace(workspaceId: 'ws')),
        isA<TileDropNoop>(),
      );
    });

    test('transfers to another workspace at the target index', () {
      final result = planTileDrop(
        windowId: const PersistentWindowId('x'),
        sourceWorkspaceId: 'other',
        target: const TileDropTarget.slot(workspaceId: 'ws', index: 1),
        destinationWindowList: windows,
      );
      expect(result, isA<TileDropTransfer>());
      result as TileDropTransfer;
      expect((result.workspaceId, result.index), ('ws', 1));
    });

    test('a workspace button appends to that workspace', () {
      final result =
          planTileDrop(
                windowId: const PersistentWindowId('x'),
                sourceWorkspaceId: 'other',
                target: const TileDropTarget.workspace(workspaceId: 'ws'),
                destinationWindowList: windows,
              )
              as TileDropTransfer;
      expect(result.index, 3);
    });
  });

  group('tileDisplayIndex', () {
    final windows = _windows(['a', 'b', 'c']);

    /// Where each slot (the launcher last) of `ws` is shown.
    List<int> shown({required String held, TileDropTarget? target}) => [
      for (var index = 0; index <= windows.length; index++)
        tileDisplayIndex(
          workspaceId: 'ws',
          windowList: windows,
          index: index,
          heldWindowId: PersistentWindowId(held),
          target: target,
          opensGap: true,
        ),
    ];

    test('every tile stays put while there is no target', () {
      expect(shown(held: 'a'), [0, 1, 2, 3]);
    });

    test('a gap opens where the held tile lands, and follows it', () {
      expect(
        shown(
          held: 'a',
          target: const TileDropTarget.slot(workspaceId: 'ws', index: 2),
        ),
        [2, 0, 1, 3],
      );
    });

    test('the gap a tile leaves closes when it lands elsewhere', () {
      expect(
        shown(
          held: 'a',
          target: const TileDropTarget.slot(workspaceId: 'other', index: 0),
        ),
        [0, 0, 1, 2],
      );
    });

    test('a workspace showing a single tile keeps every tile put', () {
      expect(
        [
          for (var index = 0; index <= windows.length; index++)
            tileDisplayIndex(
              workspaceId: 'ws',
              windowList: windows,
              index: index,
              heldWindowId: const PersistentWindowId('a'),
              target: const TileDropTarget.slot(workspaceId: 'ws', index: 2),
              opensGap: false,
            ),
        ],
        [0, 1, 2, 3],
      );
    });

    test('a tile from elsewhere opens a gap among the others', () {
      expect(
        shown(
          held: 'x',
          target: const TileDropTarget.slot(workspaceId: 'ws', index: 1),
        ),
        [0, 2, 3, 4],
      );
    });
  });

  group('tileFlightLayoutSize', () {
    const grab = TileGrab(
      pointer: 1,
      windowId: PersistentWindowId('a'),
      sourceWorkspaceId: 'ws',
      sourceScreenId: 'screen',
      originRect: Rect.fromLTWH(0, 0, 1200, 800),
      grabAnchor: Offset.zero,
      pressPosition: Offset.zero,
      globalPosition: Offset.zero,
      lifted: true,
      target: TileDropTarget.slot(workspaceId: 'ws-2', index: 0),
      landingRect: Rect.fromLTWH(0, 0, 600, 1000),
    );

    test('a held tile keeps its own layout size', () {
      expect(tileFlightLayoutSize(grab, 0.5), const Size(1200, 800));
    });

    test('a landing tile reshapes to the size of its slot', () {
      final landing = grab.copyWith(settling: true);
      expect(tileFlightLayoutSize(landing, 0), const Size(1200, 800));
      expect(tileFlightLayoutSize(landing, 0.5), const Size(900, 900));
      expect(tileFlightLayoutSize(landing, 1), const Size(600, 1000));
    });

    test('a tile flying into a workspace button only scales down', () {
      final landing = grab.copyWith(
        settling: true,
        target: const TileDropTarget.workspace(workspaceId: 'ws-2'),
        landingRect: const Rect.fromLTWH(0, 0, 56, 56),
      );
      expect(tileFlightLayoutSize(landing, 1), const Size(1200, 800));
    });
  });

  group('Super + drag', () {
    late List<(WorkspaceId, PersistentWindowId, int)> inserted;
    late ProviderContainer container;

    Future<void> pumpScreens(
      WidgetTester tester, {
      List<String> windows = const ['a', 'b', 'c'],
      List<String>? otherWindows,
      int? visible,
      int? otherVisible,
    }) async {
      inserted = [];
      container = ProviderContainer(
        overrides: [
          localizedDesktopEntryForIdProvider(
            'app',
          ).overrideWith(_NoDesktopEntry.new),
          iconFileFromQueryProvider.overrideWith((ref, query) async => null),
          for (final id in [...windows, ...?otherWindows])
            persistentWindowStateProvider(
              PersistentWindowId(id),
            ).overrideWith(_FakeWindowState.new),
          workspaceStateProvider('ws').overrideWith(
            () => _FakeWorkspaceState(
              Workspace(
                workspaceId: 'ws',
                tileableWindowList: _windows(windows),
                selectedIndex: 0,
                visibleLength: visible ?? windows.length,
              ),
              inserted,
            ),
          ),
          workspaceStateProvider('ws-2').overrideWith(
            () => _FakeWorkspaceState(
              Workspace(
                workspaceId: 'ws-2',
                tileableWindowList: _windows(otherWindows ?? const []),
                selectedIndex: 0,
                visibleLength: otherVisible ?? otherWindows?.length ?? 1,
              ),
              inserted,
            ),
          ),
          screenStateProvider('screen').overrideWith(
            () => _FakeScreenState(
              Screen(
                screenId: 'screen',
                workspaceList: ['ws'].lock,
                selectedIndex: 0,
              ),
            ),
          ),
          screenStateProvider('screen-2').overrideWith(
            () => _FakeScreenState(
              Screen(
                screenId: 'screen-2',
                workspaceList: ['ws-2'].lock,
                selectedIndex: 0,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = _viewSize;
      addTearDown(tester.view.reset);
      final first = _screen(
        screenId: 'screen',
        workspaceId: 'ws',
        windows: windows,
        origin: Offset.zero,
      );
      if (otherWindows == null) {
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: first),
        );
        return;
      }
      final otherView = _SecondView(tester)
        ..devicePixelRatio = 1
        ..physicalSize = _viewSize;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ViewCollection(
            views: [
              View(view: tester.view, child: first),
              View(
                view: otherView,
                child: _screen(
                  screenId: 'screen-2',
                  workspaceId: 'ws-2',
                  windows: otherWindows,
                  origin: _secondViewOrigin,
                ),
              ),
            ],
          ),
        ),
        wrapWithView: false,
      );
    }

    List<String> order([WorkspaceId workspaceId = 'ws']) => _ids(
      container.read(workspaceStateProvider(workspaceId)).tileableWindowList,
    );

    Future<TestGesture> superPress(WidgetTester tester, Offset position) async {
      // The test harness has no physical Super key; the compositor reports
      // it as meta on some keymaps, which `isSuperKeyPressed` accepts too.
      await simulateKeyDownEvent(LogicalKeyboardKey.metaLeft);
      addTearDown(() async {
        if (HardwareKeyboard.instance.isMetaPressed) {
          await simulateKeyUpEvent(LogicalKeyboardKey.metaLeft);
        }
      });
      return tester.startGesture(position, kind: PointerDeviceKind.mouse);
    }

    testWidgets('the tiles open a gap where the tile lands, and it lands '
        'there', (tester) async {
      await pumpScreens(tester);
      final gesture = await superPress(tester, _slot(0));
      await gesture.moveTo(_slot(2, dx: 0.5));
      await tester.pump();

      final grab = container.read(tileGrabControllerProvider);
      expect(grab?.lifted, isTrue);
      expect(
        grab?.target,
        const TileDropTarget.slot(workspaceId: 'ws', index: 2),
      );
      expect(
        grab?.landingRect,
        const Rect.fromLTWH(_tileWidth * 2, 0, _tileWidth, _tileHeight),
      );

      // The others slide left into the slot the tile left.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getCenter(find.text('b')).dx, _tileWidth / 2);
      expect(tester.getCenter(find.text('c')).dx, _tileWidth * 1.5);

      // Released, it flies into the gap; the drop commits once it lands.
      await gesture.up();
      await tester.pump();
      expect(container.read(tileGrabControllerProvider)?.settling, isTrue);
      expect(order(), ['a', 'b', 'c']);
      await _settle(tester);
      expect(order(), ['b', 'c', 'a']);
      expect(container.read(tileGrabControllerProvider), isNull);
      // Nothing moves when it commits: each tile is already where it belongs.
      expect(tester.getCenter(find.text('a')).dx, _tileWidth * 2.5);
      expect(tester.getCenter(find.text('b')).dx, _tileWidth / 2);
    });

    testWidgets('the tile sticks to its slot, then pops off under the '
        'pointer', (tester) async {
      await pumpScreens(tester);
      final heldTile = find
          .descendant(
            of: find.byType(TileGrabPreview),
            matching: find.byType(Material),
          )
          .first;
      final press = _slot(0);
      final gesture = await superPress(tester, press);
      await tester.pump();

      // Pressed: the tile itself is pushed in, around the grabbed spot.
      expect(heldTile, findsOneWidget);
      expect(tester.getSize(heldTile).width, closeTo(_tileWidth * 0.97, 0.01));
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: find.text('a'), matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
        0,
        reason: 'the slot is left empty',
      );
      expect(
        find.descendant(
          of: find.byType(TileGrabPreview),
          matching: find.byType(WindowPlaceholder),
        ),
        findsOneWidget,
        reason: 'an empty tile is carried with its placeholder, as shown',
      );

      // Below the lift distance it stretches towards the pointer, stuck.
      final pressedLeft = tester.getTopLeft(heldTile).dx;
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(container.read(tileGrabControllerProvider)?.lifted, isFalse);
      expect(tester.getTopLeft(heldTile).dx - pressedLeft, closeTo(6, 0.01));

      // Past it, the tile snaps off, shrinks and tracks the pointer.
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(container.read(tileGrabControllerProvider)?.lifted, isTrue);
      // The grab ticks every frame while held, so it never settles.
      await tester.pump(const Duration(milliseconds: 400));
      final lifted = tester.getRect(heldTile);
      // A wide tile shrinks to a 720 px long side.
      expect(lifted.width, closeTo(720, 0.01));
      final pointer = press + const Offset(50, 0);
      expect(lifted.left + lifted.width * 0.25, closeTo(pointer.dx, 0.01));
      expect(lifted.top + lifted.height * 0.5, closeTo(pointer.dy, 0.01));

      // Released over its own slot, it flies home.
      await gesture.up();
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byType(TileGrabPreview),
          matching: find.byType(Material),
        ),
        findsNothing,
      );
      expect(order(), ['a', 'b', 'c']);
    });

    testWidgets('over its own slot the gap stays home', (tester) async {
      await pumpScreens(tester);
      final gesture = await superPress(tester, _slot(1));
      await gesture.moveTo(_slot(1, dx: 0.75));
      await tester.pump();
      final grab = container.read(tileGrabControllerProvider);
      expect(grab?.lifted, isTrue);
      expect(grab?.target, isNull, reason: 'dropping there is a no-op');

      // Over the tile on its left, that tile slides right to make room.
      await gesture.moveTo(_slot(0, dx: 0.5));
      await tester.pump();
      expect(
        container.read(tileGrabControllerProvider)?.target,
        const TileDropTarget.slot(workspaceId: 'ws', index: 0),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getCenter(find.text('a')).dx, _tileWidth * 1.5);

      // The pointer now sits over the gap: the target holds still.
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(
        container.read(tileGrabControllerProvider)?.target,
        const TileDropTarget.slot(workspaceId: 'ws', index: 0),
      );
      await gesture.up();
      await _settle(tester);
      expect(order(), ['b', 'a', 'c']);
    });

    testWidgets('a press without Super does not grab the tile', (tester) async {
      await pumpScreens(tester);
      final gesture = await tester.startGesture(
        _slot(0),
        kind: PointerDeviceKind.mouse,
      );
      expect(container.read(tileGrabControllerProvider), isNull);
      await gesture.moveTo(_slot(1, dx: 0.75));
      await gesture.up();
      await tester.pump();
      expect(order(), ['a', 'b', 'c']);
    });

    testWidgets('a Super click that never moves leaves the tile in place', (
      tester,
    ) async {
      await pumpScreens(tester);
      final gesture = await superPress(tester, _slot(0, dx: 0.75));
      expect(container.read(tileGrabControllerProvider)?.lifted, isFalse);
      await gesture.up();
      await tester.pump();
      expect(order(), ['a', 'b', 'c']);
      expect(container.read(tileGrabControllerProvider), isNull);
    });

    testWidgets('Escape flies the held tile back home', (tester) async {
      await pumpScreens(tester);
      final gesture = await superPress(tester, _slot(0));
      await gesture.moveTo(_slot(2, dx: 0.75));
      await tester.pump();
      expect(
        await simulateKeyDownEvent(LogicalKeyboardKey.escape),
        isTrue,
        reason: 'the shell keeps Escape from the client',
      );
      await simulateKeyUpEvent(LogicalKeyboardKey.escape);
      final grab = container.read(tileGrabControllerProvider);
      expect(grab?.settling, isTrue);
      expect(grab?.target, isNull, reason: 'the gap closes back home');
      await gesture.up();
      await _settle(tester);
      expect(container.read(tileGrabControllerProvider), isNull);
      expect(order(), ['a', 'b', 'c']);
    });

    testWidgets('the held tile can be dropped on another monitor', (
      tester,
    ) async {
      await pumpScreens(tester, otherWindows: ['x', 'y']);
      final gesture = await superPress(tester, _slot(1));
      // Over the second view's first tile.
      await gesture.moveTo(_secondViewOrigin + _slot(0));
      await tester.pump();
      final grab = container.read(tileGrabControllerProvider);
      expect(grab?.hoveredScreenId, 'screen-2');
      expect(
        grab?.target,
        const TileDropTarget.slot(workspaceId: 'ws-2', index: 0),
      );
      expect(
        grab?.landingRect,
        _secondViewOrigin & const Size(_tileWidth, _tileHeight),
      );

      await gesture.up();
      await _settle(tester);
      expect(inserted, [('ws-2', const PersistentWindowId('b'), 0)]);
      expect(container.read(tileGrabControllerProvider), isNull);
    });

    testWidgets('over a workspace showing a single tile, a bar marks the '
        'edge and nothing moves', (tester) async {
      await pumpScreens(tester, otherWindows: ['x', 'y'], otherVisible: 1);
      final gesture = await superPress(tester, _slot(0));
      final xCenter = tester.getCenter(find.text('x'));

      // The right half of the shown tile inserts after it.
      await gesture.moveTo(_secondViewOrigin + _slot(0, dx: 0.75));
      await tester.pump();
      var grab = container.read(tileGrabControllerProvider);
      expect(
        grab?.target,
        const TileDropTarget.slot(workspaceId: 'ws-2', index: 1),
      );
      expect(grab?.insertionMark, (workspaceId: 'ws-2', index: 0, after: true));
      expect(
        grab?.landingRect,
        _secondViewOrigin & const Size(_tileWidth, _tileHeight),
      );

      // Its left half inserts before it.
      await gesture.moveTo(_secondViewOrigin + _slot(0));
      await tester.pump();
      grab = container.read(tileGrabControllerProvider);
      expect(
        grab?.target,
        const TileDropTarget.slot(workspaceId: 'ws-2', index: 0),
      );
      expect(grab?.insertionMark?.after, isFalse);

      // No gap empties the workspace: the shown tile stays.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getCenter(find.text('x')), xCenter);

      // Released, the shown tile slides out (to the right, since the tile
      // lands before it) to make room.
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getCenter(find.text('x')).dx, xCenter.dx + _tileWidth);
      await _settle(tester);
      expect(inserted, [('ws-2', const PersistentWindowId('a'), 0)]);
    });

    testWidgets('a workspace showing a single tile reorders with the bar', (
      tester,
    ) async {
      await pumpScreens(tester, visible: 1);
      final gesture = await superPress(tester, _slot(0));
      // Over its own tile, either half is no target.
      for (final dx in [0.3, 0.75]) {
        await gesture.moveTo(_slot(0, dx: dx));
        await tester.pump();
        final grab = container.read(tileGrabControllerProvider);
        expect(grab?.lifted, isTrue);
        expect(grab?.target, isNull);
        expect(grab?.insertionMark, isNull);
      }
      await gesture.up();
      await _settle(tester);
      expect(order(), ['a', 'b', 'c']);
      expect(container.read(tileGrabControllerProvider), isNull);
    });

    testWidgets('navigation scrolls the screen under the held tile', (
      tester,
    ) async {
      await pumpScreens(tester, otherWindows: ['x', 'y']);
      final gesture = await superPress(tester, _slot(0));
      await gesture.moveTo(_secondViewOrigin + const Offset(200, 100));
      await tester.pump();

      final notifier = container.read(tileGrabControllerProvider.notifier);
      expect(
        notifier.handleIntent(const NavigateIntent(NavigationDirection.right)),
        isTrue,
      );
      expect(container.read(workspaceStateProvider('ws-2')).selectedIndex, 1);
      // The workspace the grab started from keeps its selection.
      expect(container.read(workspaceStateProvider('ws')).selectedIndex, 0);
      expect(
        notifier.handleIntent(const MoveIntent(NavigationDirection.left)),
        isTrue,
        reason: 'keyboard moves would fight the pointer',
      );

      await gesture.up();
      await _settle(tester);
      expect(
        notifier.handleIntent(const NavigateIntent(NavigationDirection.right)),
        isFalse,
        reason: 'navigation is back to the focused context',
      );
    });
  });
}
