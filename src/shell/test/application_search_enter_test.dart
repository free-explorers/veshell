import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview_shortcuts.dart';
import 'package:shell/overview/widget/search/search_engine.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/shortcut_manager/widget/shortcut_manager.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_manager_state.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

/// Records the ephemeral window the overview asks the manager to create.
class _FakeWindowManager extends WindowManager {
  EphemeralWindowId? created;

  @override
  WindowManagerState build() => WindowManagerState(windows: <WindowId>{}.lock);

  @override
  EphemeralWindowId createEphemeralWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
    ScreenId screenId,
  ) {
    created = const EphemeralWindowId('e-fake');
    return created!;
  }

  @override
  void removeWindow(WindowId windowId) {}
}

class _FakeEphemeralWindowState extends EphemeralWindowState {
  @override
  EphemeralWindow build(EphemeralWindowId windowId) => EphemeralWindow(
    windowId: windowId,
    properties: const WindowProperties(appId: 'org.example.App'),
    screenId: 'test',
  );

  @override
  Future<Process?> launchSelf() async => null;
}

class _NoDesktopEntry extends LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => null;
}

void main() {
  const screenId = 'test';

  List<LocalizedDesktopEntry> appEntries() => [
    LocalizedDesktopEntry(
      desktopEntry: const DesktopEntry(entries: {}),
      entries: {
        DesktopEntryKey.name.string: 'Alpha',
        DesktopEntryKey.comment.string: 'First',
      },
    ),
    LocalizedDesktopEntry(
      desktopEntry: const DesktopEntry(entries: {}),
      entries: {
        DesktopEntryKey.name.string: 'Beta',
        DesktopEntryKey.comment.string: 'Second',
      },
    ),
  ];

  testWidgets('Enter launches the first result after a search', (tester) async {
    final entryList = appEntries();
    final manager = _FakeWindowManager();
    final navigation = <ShortcutActivator, Intent>{
      LogicalKeySet.fromSet({LogicalKeyboardKey.enter}): const ActivateIntent(),
      LogicalKeySet.fromSet({LogicalKeyboardKey.numpadEnter}):
          const ActivateIntent(),
    };
    final container = ProviderContainer(
      overrides: [
        for (final text in ['', 'a'])
          appDrawerFilteredDesktopEntriesProvider(
            text,
          ).overrideWith((ref) async => entryList),
        hotkeysActivatorProvider.overrideWithValue(navigation),
        windowManagerProvider.overrideWith(() => manager),
        ephemeralWindowStateProvider.overrideWith(
          _FakeEphemeralWindowState.new,
        ),
        localizedDesktopEntryForIdProvider(
          'org.example.App',
        ).overrideWith(_NoDesktopEntry.new),
      ],
    );
    addTearDown(container.dispose);

    // Mirrors the real tree: `VeshellShortcutManager` lives inside the
    // `MaterialApp` (see `MonitorWidget`), below Flutter's
    // `DefaultTextEditingShortcuts`. The overview's search pane also binds
    // `Enter` locally, so activation works either way.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              VeshellShortcutManager(child: child ?? const SizedBox.shrink()),
          home: const CurrentScreenId(
            screenId: screenId,
            child: Scaffold(body: OverviewShortcuts(child: SearchEngine())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();
    expect(
      container.read(overviewStateProvider(screenId)).selectedIndex,
      0,
      reason: 'typing selects the first result',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      manager.created,
      isNotNull,
      reason: 'Enter on the first result launches it',
    );
  });
}
