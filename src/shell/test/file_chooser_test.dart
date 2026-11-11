import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/capture/widget/capture_prompt_overlay.dart';
import 'package:shell/file_chooser/model/file_chooser_request/file_chooser_request.serializable.dart';
import 'package:shell/file_chooser/provider/file_chooser_for_window.dart';
import 'package:shell/file_chooser/provider/file_chooser_request.dart';
import 'package:shell/file_chooser/widget/file_chooser_dialog.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/model/file_explorer_settings.dart';
import 'package:shell/file_explorer/provider/directory_listing.dart';
import 'package:shell/file_explorer/provider/file_explorer_settings.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/window/model/window_id.serializable.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes a file chooser request with filters', () {
    final message = FileChooserRequestMessage.fromJson({
      'requestHandle': '/request/1',
      'consentToken': 7,
      'appName': 'Brave',
      'title': 'Save as',
      'mode': 'save',
      'multiple': false,
      'directory': false,
      'acceptLabel': 'Save',
      'currentFolder': '/home/user',
      'currentFile': null,
      'currentName': 'report.pdf',
      'files': <String>[],
      'filters': [
        {
          'name': 'PDF',
          'patterns': [
            {'kind': 0, 'pattern': '*.pdf'},
          ],
        },
      ],
    });
    expect(message.mode, FileChooserMode.save);
    expect(message.currentName, 'report.pdf');
    expect(message.filters.single.name, 'PDF');
    expect(message.filters.single.patterns.single.pattern, '*.pdf');
  });

  test('the dialog opens on the requester monitor when it is connected', () {
    expect(
      trustedDialogMonitorName(
        requesterMonitorName: 'DP-2',
        connectedMonitorNameList: const ['DP-1', 'DP-2'],
        focusedMonitorName: 'DP-1',
      ),
      'DP-2',
    );
    // No resolved requester: fall back to the focused monitor.
    expect(
      trustedDialogMonitorName(
        requesterMonitorName: null,
        connectedMonitorNameList: const ['DP-1', 'DP-2'],
        focusedMonitorName: 'DP-1',
      ),
      'DP-1',
    );
    // Requester monitor unplugged since the request: fall back too.
    expect(
      trustedDialogMonitorName(
        requesterMonitorName: 'HDMI-1',
        connectedMonitorNameList: const ['DP-1'],
        focusedMonitorName: 'DP-1',
      ),
      'DP-1',
    );
  });

  test('a request resolves to its owning window container', () {
    const owner = WindowId.persistent('tile-1');
    final request = _saveRequest().copyWith(metaWindowId: 'mw-1');
    final container = ProviderContainer(
      overrides: [
        fileExplorerSettingsProvider.overrideWithValue(
          const FileExplorerSettings(showHidden: true),
        ),
        fileChooserRequestProvider.overrideWith(
          () => _FakeFileChooserRequest(request),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(metaWindowWindowMapProvider.notifier).set('mw-1', owner);

    expect(container.read(fileChooserForWindowProvider(owner)), request);
    expect(
      container.read(
        fileChooserForWindowProvider(const WindowId.persistent('other')),
      ),
      isNull,
    );
  });

  testWidgets('the provider answers the compositor with the decision', (
    tester,
  ) async {
    final calls = _recordPlatformCalls(tester);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
      ..listen(fileChooserRequestProvider, (_, _) {})
      ..read(fileChooserRequestProvider);

    // Deliver the compositor's incoming method call through the real
    // PlatformManager's channel handler.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'platform',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('file_chooser_request', _saveRequest().toJson()),
      ),
      (_) {},
    );
    await tester.pump();
    expect(container.read(fileChooserRequestProvider)?.consentToken, 7);

    container.read(fileChooserRequestProvider.notifier).approve([
      'file:///home/user/report.pdf',
    ]);
    await tester.pump();

    expect(container.read(fileChooserRequestProvider), isNull);
    expect(calls.single.method, 'file_chooser_decision');
    final arguments = calls.single.arguments as Map;
    expect(arguments['consentToken'], 7);
    expect(arguments['outcome'], 'approved');
    expect(arguments['uris'], ['file:///home/user/report.pdf']);
  });

  testWidgets('the save dialog offers the suggested name and confirms it', (
    tester,
  ) async {
    final calls = _recordPlatformCalls(tester);
    final request = _saveRequest();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileExplorerSettingsProvider.overrideWithValue(
            const FileExplorerSettings(showHidden: true),
          ),
          fileChooserRequestProvider.overrideWith(
            () => _FakeFileChooserRequest(request),
          ),
          directoryListingProvider.overrideWith(
            (ref, path) async => const <FileEntry>[],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: shellLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileChooserDialog(request: request)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The suggested save name is prefilled.
    expect(find.text('report.pdf'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(calls.single.method, 'file_chooser_decision');
    final arguments = calls.single.arguments as Map;
    expect(arguments['outcome'], 'approved');
    expect(arguments['uris'], ['file:///home/user/report.pdf']);
  });

  testWidgets('the top-right close button cancels the request', (tester) async {
    final calls = _recordPlatformCalls(tester);
    final request = _saveRequest();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileExplorerSettingsProvider.overrideWithValue(
            const FileExplorerSettings(showHidden: true),
          ),
          fileChooserRequestProvider.overrideWith(
            () => _FakeFileChooserRequest(request),
          ),
          directoryListingProvider.overrideWith(
            (ref, path) async => const <FileEntry>[],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: shellLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileChooserDialog(request: request)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(calls.single.method, 'file_chooser_decision');
    final arguments = calls.single.arguments as Map;
    expect(arguments['outcome'], 'cancelled');
    expect(arguments['uris'], isEmpty);
  });

  group('keyboard', () {
    final listing = [
      const FileEntry(
        name: 'Documents',
        path: DirectoryPath('/home/user/Documents'),
        isDirectory: true,
        size: 0,
      ),
      const FileEntry(
        name: 'alpha.png',
        path: DirectoryPath('/home/user/alpha.png'),
        isDirectory: false,
        size: 1,
      ),
      const FileEntry(
        name: 'beta.txt',
        path: DirectoryPath('/home/user/beta.txt'),
        isDirectory: false,
        size: 1,
      ),
    ];

    /// Pumps the chooser beside a focused node standing for the hosting
    /// tile, which keeps the keyboard unless the chooser takes it.
    Future<void> pumpChooser(
      WidgetTester tester,
      FileChooserRequestMessage request,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileExplorerSettingsProvider.overrideWithValue(
              const FileExplorerSettings(),
            ),
            fileChooserRequestProvider.overrideWith(
              () => _FakeFileChooserRequest(request),
            ),
            directoryListingProvider.overrideWith(
              (ref, path) async =>
                  path == const DirectoryPath('/home/user') ? listing : [],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: shellLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  const Focus(autofocus: true, child: SizedBox(height: 1)),
                  Expanded(child: FileChooserDialog(request: request)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the save dialog focuses the name with its base selected',
      (tester) async {
        await pumpChooser(tester, _saveRequest());

        final field = tester.widget<TextField>(
          find.widgetWithText(TextField, 'report.pdf'),
        );
        expect(field.focusNode!.hasFocus, isTrue);
        expect(
          field.controller!.selection,
          const TextSelection(baseOffset: 0, extentOffset: 6),
        );

        // Typing replaces the base name and keeps the extension.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'invoice.pdf',
            selection: TextSelection.collapsed(offset: 7),
          ),
        );
        await tester.pump();
        expect(find.text('invoice.pdf'), findsOneWidget);
      },
      // Desktop text fields select all on focus: the extension must still be
      // left out.
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('the open dialog searches and opens with the keyboard', (
      tester,
    ) async {
      final calls = _recordPlatformCalls(tester);
      await pumpChooser(tester, _openRequest());

      final search = find.byType(TextField).first;
      expect(
        tester.widget<TextField>(search).focusNode!.hasFocus,
        isTrue,
        reason: 'typing must reach the search field, not the window behind',
      );

      await tester.enterText(search, 'bet');
      await tester.pumpAndSettle();
      expect(find.text('alpha.png'), findsNothing);
      expect(find.text('beta.txt'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(calls.single.method, 'file_chooser_decision');
      expect((calls.single.arguments as Map)['uris'], [
        'file:///home/user/beta.txt',
      ]);
    });

    testWidgets('the default type filter narrows the listing', (tester) async {
      await pumpChooser(
        tester,
        _openRequest().copyWith(
          filters: [
            FileChooserFilterMessage(
              name: 'Images',
              patterns: [
                FileChooserPatternMessage(kind: 1, pattern: 'image/*'),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('alpha.png'), findsOneWidget);
      expect(find.text('beta.txt'), findsNothing);
    });

    testWidgets(
      'the folder picker lists folders and returns the selected one',
      (tester) async {
        final calls = _recordPlatformCalls(tester);
        await pumpChooser(tester, _openRequest().copyWith(directory: true));

        expect(find.text('alpha.png'), findsNothing);
        await tester.tap(find.text('Documents'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Select folder'));
        await tester.pumpAndSettle();

        expect((calls.single.arguments as Map)['uris'], [
          'file:///home/user/Documents',
        ]);
      },
    );
  });
}

FileChooserRequestMessage _saveRequest() => FileChooserRequestMessage(
  requestHandle: '/request/1',
  consentToken: 7,
  appName: 'Brave',
  title: 'Save as',
  mode: FileChooserMode.save,
  multiple: false,
  directory: false,
  files: const [],
  filters: const [],
  currentFolder: '/home/user',
  currentName: 'report.pdf',
);

/// Records every `platform` method-channel invocation the shell sends.
List<MethodCall> _recordPlatformCalls(WidgetTester tester) {
  final calls = <MethodCall>[];
  const channel = MethodChannel('platform', JSONMethodCodec());
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    calls.add(call);
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return calls;
}

class _FakeFileChooserRequest extends FileChooserRequest {
  _FakeFileChooserRequest(this.request);

  final FileChooserRequestMessage request;

  @override
  FileChooserRequestMessage? build() => request;
}

FileChooserRequestMessage _openRequest() => _saveRequest().copyWith(
  title: '',
  mode: FileChooserMode.open,
  currentName: null,
);
