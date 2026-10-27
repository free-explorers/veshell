import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/installed_icon_themes.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/widget/theme/icon_theme_editor.dart';

void main() {
  testWidgets('lists installed themes and offers the letter placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          installedIconThemeNamesProvider.overrideWithValue([
            'Adwaita',
            'breeze',
          ]),
          for (final theme in ['Adwaita', 'breeze'])
            iconThemePreviewProvider(theme).overrideWith((ref) async => null),
          jsonValueByPathProvider(
            'theme.iconTheme',
          ).overrideWithValue('Adwaita'),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: IconThemeEditor(
              path: 'theme.iconTheme',
              property: SettingProperty<String>(
                name: 'Icon Theme',
                description: 'Icon theme',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Letter placeholders'), findsOneWidget);
    expect(find.text('Adwaita'), findsWidgets);
    expect(find.text('breeze'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
