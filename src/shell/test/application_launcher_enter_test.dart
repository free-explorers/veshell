import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_drawer.dart';

void main() {
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

  testWidgets('Enter launches the first matching application', (tester) async {
    final entryList = appEntries();
    final launched = <LocalizedDesktopEntry>[];
    final container = ProviderContainer(
      overrides: [
        appDrawerFilteredDesktopEntriesProvider(
          '',
        ).overrideWith((ref) async => entryList),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AppDrawer(onSelect: launched.add)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing launches until the search is accepted.
    expect(launched, isEmpty);

    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.entries[DesktopEntryKey.name.string], 'Alpha');
  });
}
