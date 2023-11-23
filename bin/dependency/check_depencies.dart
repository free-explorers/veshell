import 'dart:io';

import '../util.dart';
import 'package_manager/apt.dart';
import 'package_manager/dnf.dart';
import 'package_manager/package_manager_base.dart';
import 'package_manager/pacman.dart';

const packageManagerSet = <PackageManagerBase>{Pacman(), Apt(), Dnf()};

Future<void> check() async {
  print('Checking dependencies...\n');
  if (!await isCommandAvailable('cargo')) {
    print(
        'cargo is not installed. Install it using https://rustup.rs installer');
    print(
        "> ${importantColor("curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh")}");
  }

  PackageManagerBase? packageManager;

  for (final manager in packageManagerSet) {
    if (packageManager != null) {
      break;
    }

    if (await manager.isInstalled() == 0) {
      packageManager = manager;
    }
  }

  if (packageManager == null) {
    print(errorColor(
        "No supported package manager found. Can't check dependencies."));
    exit(1);
  }

  final missingDependencyList = await packageManager.missingDependencyList();

  if (missingDependencyList.isNotEmpty) {
    print(errorColor(
        'Missing dependencies: ${missingDependencyList.join(', ')}'));
    print('You can install them with');
    print(
        '> ${importantColor(packageManager.printInstallDependenciesCommand(missingDependencyList))}');
    exit(1);
  }

  print(successColor('All dependencies are installed.\n'));
}
