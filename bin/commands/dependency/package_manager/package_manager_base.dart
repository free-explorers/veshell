abstract class PackageManagerBase {
  const PackageManagerBase();
  String get make;
  String get cmake;
  String get clang;
  String get ninja;
  String get gtk3;
  String get seat;
  String get libinput;
  String get gbm;
  String get openssl;

  List<String> get dependencyList {
    return [
      cmake,
      clang,
      ninja,
      gtk3,
      seat,
      libinput,
      gbm,
      openssl,
    ];
  }

  Future<int> isInstalled();
  Future<int> isPackageInstalled(String packageName);
  String printInstallDependenciesCommand(List<String> dependencyList);

  Future<List<String>> missingDependencyList() async {
    final missingDependencies = <String>[];
    for (final dependency in dependencyList) {
      if (await isPackageInstalled(dependency) != 0) {
        missingDependencies.add(dependency);
      }
    }
    return missingDependencies;
  }
}
