import 'package:flutter_test/flutter_test.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';

void main() {
  test('decodes the Proton context sent by the embedder', () {
    final info = ProcessInfoMessage.fromJson({
      'pid': 42,
      'cmdline': [r'Z:\home\user\games\Game.exe'],
      'exe': '/opt/Proton/files/bin/wine64-preloader',
      'wine': {
        'prefix': '/steam/compatdata/1091500/pfx',
        'steamAppId': '1091500',
        'compatDataPath': '/steam/compatdata/1091500',
        'compatToolPaths': ['/opt/Proton'],
      },
    });

    final wine = info.wine!;
    expect(wine.isProton, isTrue);
    expect(wine.steamAppId, '1091500');
    expect(wine.compatToolPaths, ['/opt/Proton']);
  });

  test('plain Wine is not Proton, and native processes carry no context', () {
    expect(
      WineInfoMessage.fromJson({'prefix': '/home/user/.wine'}).isProton,
      isFalse,
    );
    expect(ProcessInfoMessage.fromJson({'pid': 1}).wine, isNull);
  });
}
