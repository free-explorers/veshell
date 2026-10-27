import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/icon_themes.dart';
import 'package:shell/settings/provider/state/icon_theme_setting.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';

void main() {
  test('the letter theme skips the installed icon theme entirely', () async {
    final container = ProviderContainer(
      overrides: [
        iconThemeSettingProvider.overrideWithValue(letterIconThemeId),
        iconThemesProvider.overrideWith(
          (ref) => fail('The themed icon pipeline must not be loaded'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = iconFileFromQueryProvider(
      IconQuery(name: 'files', size: 48, extensions: const ['svg', 'png']),
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    expect(await container.read(provider.future), isNull);
  });
}
