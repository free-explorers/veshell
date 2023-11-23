import '../../util.dart';
import 'package_manager_base.dart';

class Apt extends PackageManagerBase {
  const Apt();
  @override
  String get make => 'make';

  @override
  String get cmake => 'cmake';

  @override
  String get clang => 'clang';

  @override
  String get ninja => 'ninja-build';

  @override
  String get gtk3 => 'libgtk-3-dev';

  @override
  String get seat => 'libseat-dev';

  @override
  String get libinput => 'libinput-dev';

  @override
  String get gbm => 'libgbm-dev';

  @override
  String get openssl => 'openssl';

  @override
  String printInstallDependenciesCommand(List<String> dependencyList) {
    return 'sudo apt install -y ${dependencyList.join(" ")}';
  }

  @override
  Future<int> isPackageInstalled(String packageName) async {
    return runProcess('dpkg', ['-s', packageName], verbose: false);
  }

  @override
  Future<int> isInstalled() async {
    return runProcess('which', ['apt'], verbose: false);
  }
}
