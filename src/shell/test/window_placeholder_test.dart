import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/resume_context.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/widget/window_placeholder.dart';

const _windowId = PersistentWindowId('placeholder-test');

class _FixedLocalizedEntry extends LocalizedDesktopEntryForId {
  _FixedLocalizedEntry(this._entry);

  final LocalizedDesktopEntry? _entry;

  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => _entry;
}

LocalizedDesktopEntry _entry(String name) => LocalizedDesktopEntry(
  desktopEntry: const DesktopEntry(entries: {}),
  entries: {DesktopEntryKey.name.string: name},
);

Future<void> _pumpPlaceholder(
  WidgetTester tester,
  PersistentWindow window, {
  bool hasDesktopEntry = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localizedDesktopEntryForIdProvider(
          window.properties.appId,
        ).overrideWith(
          () => _FixedLocalizedEntry(hasDesktopEntry ? _entry('Brave') : null),
        ),
        iconFileFromQueryProvider.overrideWith((ref, query) async => null),
      ],
      child: MaterialApp(
        localizationsDelegates: shellLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1280,
              height: 800,
              child: WindowPlaceholder(window: window, isSelected: false),
            ),
          ),
        ),
      ),
    ),
  );
  // Resolve the desktop entry future and paint the resolved name.
  await tester.pump();
}

PersistentWindow _window({String? title, ResumeContext? resumeContext}) =>
    PersistentWindow(
      windowId: _windowId,
      properties: WindowProperties(appId: 'brave-browser', title: title),
      resumeContext: resumeContext,
    );

void main() {
  testWidgets('Start names the application, never the saved title', (
    tester,
  ) async {
    const savedTitle =
        'Restore ~ — an arbitrarily long browser page title that must not '
        'become the placeholder action';

    await _pumpPlaceholder(tester, _window(title: savedTitle));

    expect(find.text('Start Brave'), findsOneWidget);
    expect(find.textContaining(savedTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long resume summary stays on one ellipsized line', (
    tester,
  ) async {
    const savedTitle =
        'A very long resume summary that would otherwise wrap onto several '
        'lines and push the placeholder content out of its layout';
    final window = _window(
      title: savedTitle,
      resumeContext: ResumeContext(capturedAt: DateTime(2026)),
    );

    await _pumpPlaceholder(tester, window);

    final label = tester.widget<Text>(find.text('Resume $savedTitle'));
    expect(label.maxLines, 1);
    expect(label.softWrap, isFalse);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Resume ignores a generic application working directory', (
    tester,
  ) async {
    final window = _window(
      resumeContext: ResumeContext(
        workingDirectory: Platform.environment['HOME'],
        capturedAt: DateTime(2026),
      ),
    );

    await _pumpPlaceholder(tester, window);

    expect(find.text('Resume'), findsOneWidget);
    expect(find.textContaining('~'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a desktop entry the saved title and command are shown', (
    tester,
  ) async {
    final window = _window(
      title: 'Saved document title',
      resumeContext: ResumeContext(
        argv: const ['/usr/bin/app', '--flag', 'document.txt'],
        capturedAt: DateTime(2026),
      ),
    );

    await _pumpPlaceholder(tester, window, hasDesktopEntry: false);

    expect(find.text('Saved document title'), findsOneWidget);
    final execField = tester.widget<TextField>(find.byType(TextField));
    expect(execField.controller!.text, '/usr/bin/app --flag document.txt');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'without a desktop entry the executable backs the saved command',
    (tester) async {
      final window = _window(
        resumeContext: ResumeContext(
          executable: '/usr/bin/app',
          capturedAt: DateTime(2026),
        ),
      );

      await _pumpPlaceholder(tester, window, hasDesktopEntry: false);

      final execField = tester.widget<TextField>(find.byType(TextField));
      expect(execField.controller!.text, '/usr/bin/app');
      expect(tester.takeException(), isNull);
    },
  );
}
