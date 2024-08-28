import '../../../util.dart';
import 'package_manager_base.dart';

class Dnf extends PackageManagerBase {
  const Dnf();
  @override
  String get make => 'make';

  @override
  String get cmake => 'cmake';

  @override
  String get clang => 'clang';

  @override
  String get ninja => 'ninja-build';

  @override
  String get gtk3 => 'gtk3-devel';

  @override
  String get seat => 'libseat-devel';

  @override
  String get libinput => 'libinput-devel';

  @override
  String get gbm => 'mesa-libgbm-devel';

  @override
  String get openssl => 'openssl-devel';

  @override
  String printInstallDependenciesCommand(List<String> dependencyList) {
    return 'sudo dnf install -y ${dependencyList.join(" ")}';
  }

  @override
  Future<int> isPackageInstalled(String packageName) async {
    return runProcess(
      'dnf',
      ['list', 'installed', packageName],
      verbose: false,
    );
  }

  @override
  Future<int> isInstalled() async {
    return runProcess('which', ['dnf'], verbose: false);
  }
}
