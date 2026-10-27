import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shell/settings/provider/util/icon_theme_preview.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';

void main() {
  late Directory root;
  late String icons;

  void writeTheme(String name, String index, {List<String> files = const []}) {
    final directory = Directory(path.join(icons, name))
      ..createSync(recursive: true);
    File(path.join(directory.path, 'index.theme')).writeAsStringSync(index);
    for (final file in files) {
      File(path.join(directory.path, file))
        ..createSync(recursive: true)
        ..writeAsStringSync('<svg/>');
    }
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('icon-theme-preview-');
    icons = path.join(root.path, 'icons');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('picks the folder icon closest to the requested size', () {
    writeTheme(
      'Sample',
      '''
[Icon Theme]
Directories=16/places,32/places

[16/places]
Size=16

[32/places]
Size=32
''',
      files: ['16/places/folder.svg', '32/places/folder.svg'],
    );

    expect(
      findIconThemePreview('Sample', baseDirectories: [icons])?.path,
      path.join(icons, 'Sample', '32/places/folder.svg'),
    );
  });

  test('follows inherited themes but not hicolor', () {
    writeTheme('Child', '''
[Icon Theme]
Inherits=Parent,hicolor
Directories=
''');
    writeTheme(
      'Parent',
      '''
[Icon Theme]
Directories=scalable/places

[scalable/places]
Size=48
Type=Scalable
MinSize=8
MaxSize=512
''',
      files: ['scalable/places/folder.svg'],
    );
    writeTheme(
      'hicolor',
      '''
[Icon Theme]
Directories=32/places

[32/places]
Size=32
''',
      files: ['32/places/user-home.svg'],
    );

    expect(
      findIconThemePreview('Child', baseDirectories: [icons])?.path,
      path.join(icons, 'Parent', 'scalable/places/folder.svg'),
    );
    expect(findIconThemePreview('hicolor', baseDirectories: [icons]), isNull);
  });

  test('installed themes exclude cursor-only themes', () {
    writeTheme('Icons', '[Icon Theme]\nDirectories=32/places\n');
    writeTheme('Pointer', '[Icon Theme]\nName=Pointer\nInherits=Adwaita\n');

    expect(installedIconThemes(environment: {'XDG_DATA_DIRS': root.path}), {
      'Icons',
    });
  });
}
