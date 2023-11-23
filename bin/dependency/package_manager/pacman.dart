import '../../util.dart';
import 'package_manager_base.dart';

class Pacman extends PackageManagerBase {
  const Pacman();
  @override
  String get make => 'make';

  @override
  String get cmake => 'cmake';

  @override
  String get clang => 'clang';

  @override
  String get ninja => 'ninja';

  @override
  String get gtk3 => 'gtk3';

  @override
  String get seat => 'seatd';

  @override
  String get libinput => 'libinput';

  @override
  String get gbm => 'libgbm';

  @override
  String get openssl => 'openssl';

  @override
  String printInstallDependenciesCommand(List<String> dependencyList) {
    return 'sudo pacman -S --needed ${dependencyList.join(" ")}';
  }

  @override
  Future<int> isPackageInstalled(String packageName) async {
    return runProcess('pacman', ['-Q', packageName], verbose: false);
  }

  @override
  Future<int> isInstalled() async {
    return runProcess('command', ['-v', 'pacman'], verbose: false);
  }
}
