import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Notification;
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/capture/provider/recording_workspaces.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/notification/model/notification.serializable.dart';
import 'package:shell/notification/provider/notification_routing.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/screen/provider/workspace_display_mode.dart';
import 'package:shell/screen/widget/workspace_icon.dart';
import 'package:shell/screen/widget/workspace_list.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

const _screen = 'screen-1';
const _workspace = 'ws-1';

/// Windows `w0`, `w1`... of the applications named by this map.
const _appIdOfWindow = {
  'w0': 'editor',
  'w1': 'browser',
  'w2': 'editor',
  'w3': 'player',
  'w4': 'chat',
  'w5': 'mail',
};

class _FixedScreenState extends ScreenState {
  @override
  Screen build(ScreenId screenId) => Screen(
    screenId: screenId,
    workspaceList: const IListConst<String>([_workspace]),
    selectedIndex: 0,
  );
}

class _FixedWindowState extends PersistentWindowState {
  @override
  PersistentWindow build(PersistentWindowId windowId) => PersistentWindow(
    windowId: windowId,
    properties: WindowProperties(appId: _appIdOfWindow[windowId.uuid]!),
  );
}

class _NoLocalizedEntry extends LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => null;
}

class _FakeWorkspaceState extends WorkspaceState {
  _FakeWorkspaceState(this._initial);
  final Workspace _initial;

  @override
  Workspace build(WorkspaceId workspaceId) => _initial;

  @override
  Future<void> setForcedCategory(WorkspaceCategory? category) async {
    state = state.copyWith(forcedCategory: category);
  }
}

Workspace _workspaceOf(
  int windowCount, {
  WorkspaceCategory? category = WorkspaceCategory.Development,
  WorkspaceCategory? forcedCategory,
}) => Workspace(
  workspaceId: _workspace,
  tileableWindowList: [
    for (var i = 0; i < windowCount; i++) PersistentWindowId('w$i'),
  ].lock,
  selectedIndex: 0,
  visibleLength: 1,
  category: category,
  forcedCategory: forcedCategory,
);

Future<_FakeWorkspaceState> _pumpButton(
  WidgetTester tester,
  Workspace workspace,
  WorkspaceDisplayMode mode,
) async {
  final state = _FakeWorkspaceState(workspace);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        screenStateProvider(_screen).overrideWith(_FixedScreenState.new),
        workspaceStateProvider(_workspace).overrideWith(() => state),
        persistentWindowStateProvider.overrideWith2((_) => _FixedWindowState()),
        localizedDesktopEntryForIdProvider.overrideWith2(
          (_) => _NoLocalizedEntry(),
        ),
        currentWorkspaceDisplayModeProvider.overrideWithValue(mode),
        unreadNotificationsForWorkspaceProvider(
          _workspace,
        ).overrideWithValue(const IListConst<Notification>([])),
        recordingWorkspacesProvider.overrideWithValue(
          const ISetConst<WorkspaceId>({}),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 48,
              height: 48,
              child: WorkspaceListButton(
                workspaceId: _workspace,
                screenId: _screen,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return state;
}

Finder get _appIcons => find.byType(AppIconById);

WorkspaceCategory? _shownCategory(WidgetTester tester) {
  final icons = find.byType(CategoryIcon);
  if (icons.evaluate().isEmpty) return null;
  return tester.widget<CategoryIcon>(icons).category;
}

void main() {
  test('applications rank by presence, ties in order of appearance', () {
    expect(rankApplications(['a', 'b', 'c', 'b', 'd', 'c', 'b']), [
      'b',
      'c',
      'a',
      'd',
    ]);
  });

  group('split icon shares', () {
    const size = Size.square(24);
    bool inShare(int index, int count, Offset point) => SplitIconShareClipper(
      index: index,
      count: count,
    ).getClip(size).contains(point);
    List<int> sharesAt(int count, Offset point) => [
      for (var i = 0; i < count; i++)
        if (inShare(i, count, point)) i,
    ];

    test('two: left and right halves, split by a gap', () {
      expect(sharesAt(2, const Offset(4, 12)), [0]);
      expect(sharesAt(2, const Offset(20, 12)), [1]);
      expect(sharesAt(2, const Offset(12, 12)), isEmpty);
    });

    test('three: wedges of a disc, the first on top', () {
      expect(sharesAt(3, const Offset(12, 3)), [0]);
      expect(sharesAt(3, const Offset(19, 17)), [1]);
      expect(sharesAt(3, const Offset(5, 17)), [2]);
      // Between the wedges, and outside the disc.
      expect(sharesAt(3, const Offset(12, 20)), isEmpty);
      expect(sharesAt(3, const Offset(1, 1)), isEmpty);
    });

    test('four: quarters in reading order, split by gaps', () {
      expect(sharesAt(4, const Offset(4, 4)), [0]);
      expect(sharesAt(4, const Offset(20, 4)), [1]);
      expect(sharesAt(4, const Offset(4, 20)), [2]);
      expect(sharesAt(4, const Offset(20, 20)), [3]);
      expect(sharesAt(4, const Offset(12, 4)), isEmpty);
      expect(sharesAt(4, const Offset(4, 12)), isEmpty);
    });
  });

  group('workspace icon', () {
    testWidgets('hybrid: a single application shows its icon', (tester) async {
      // w0 and w2 are both the editor.
      final workspace = _workspaceOf(1).copyWith(
        tileableWindowList: const [
          PersistentWindowId('w0'),
          PersistentWindowId('w2'),
        ].lock,
      );
      await _pumpButton(tester, workspace, WorkspaceDisplayMode.hybrid);
      expect(_appIcons, findsOneWidget);
      expect(_shownCategory(tester), isNull);
    });

    testWidgets('hybrid: several applications show the category', (
      tester,
    ) async {
      await _pumpButton(tester, _workspaceOf(2), WorkspaceDisplayMode.hybrid);
      expect(_appIcons, findsNothing);
      expect(_shownCategory(tester), WorkspaceCategory.Development);
    });

    testWidgets('hybrid: several uncategorized applications share the icon', (
      tester,
    ) async {
      await _pumpButton(
        tester,
        _workspaceOf(2, category: null),
        WorkspaceDisplayMode.hybrid,
      );
      expect(_appIcons, findsNWidgets(2));
    });

    testWidgets('category: always the category, System when unknown', (
      tester,
    ) async {
      await _pumpButton(
        tester,
        _workspaceOf(1, category: null),
        WorkspaceDisplayMode.category,
      );
      expect(_shownCategory(tester), WorkspaceCategory.System);
    });

    for (final (windows, shares) in [(1, 1), (2, 2), (4, 3), (5, 4), (6, 4)]) {
      testWidgets('application: $windows windows share $shares ways', (
        tester,
      ) async {
        await _pumpButton(
          tester,
          _workspaceOf(windows),
          WorkspaceDisplayMode.application,
        );
        expect(_appIcons, findsNWidgets(shares));
        expect(_shownCategory(tester), isNull);
        // The editor has two windows from four on: it takes the first share.
        if (windows >= 4) {
          expect(tester.widgetList<AppIconById>(_appIcons).first.id, 'editor');
        }
      });
    }

    testWidgets('a fixed category wins over the mode, even when empty', (
      tester,
    ) async {
      await _pumpButton(
        tester,
        _workspaceOf(3, forcedCategory: WorkspaceCategory.Game),
        WorkspaceDisplayMode.application,
      );
      expect(_appIcons, findsNothing);
      expect(_shownCategory(tester), WorkspaceCategory.Game);

      // A new scope, not the previous workspace state.
      await tester.pumpWidget(const SizedBox());
      await _pumpButton(
        tester,
        _workspaceOf(0, forcedCategory: WorkspaceCategory.Office),
        WorkspaceDisplayMode.hybrid,
      );
      expect(_shownCategory(tester), WorkspaceCategory.Office);
    });

    testWidgets('the button menu fixes the category, then releases it', (
      tester,
    ) async {
      final state = await _pumpButton(
        tester,
        _workspaceOf(2),
        WorkspaceDisplayMode.application,
      );
      Future<void> pick(String label) async {
        await tester.tap(
          find.byType(WorkspaceListButton),
          buttons: kSecondaryButton,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Workspace icon'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await pick('Game');
      expect(state.state.forcedCategory, WorkspaceCategory.Game);
      expect(_shownCategory(tester), WorkspaceCategory.Game);

      await pick('Automatic');
      expect(state.state.forcedCategory, isNull);
      expect(_appIcons, findsNWidgets(2));
    });
  });
}
