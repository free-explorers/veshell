import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../util.dart';
import 'package_manager/apt.dart';
import 'package_manager/dnf.dart';
import 'package_manager/package_manager_base.dart';
import 'package_manager/pacman.dart';

const packageManagerSet = <PackageManagerBase>{Pacman(), Apt(), Dnf()};

Future<void> check(Logger logger) async {
  logger.info('Checking dependencies...\n');
  if (!await isCommandAvailable('cargo')) {
    logger
      ..info(
        'cargo is not installed. Install it using https://rustup.rs installer',
      )
      ..info(
        "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh",
        style: commandStyle,
      );
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
    logger.err(
      "No supported package manager found. Can't check dependencies.",
    );
    exit(1);
  }

  final missingDependencyList = await packageManager.missingDependencyList();

  if (missingDependencyList.isNotEmpty) {
    logger
      ..err(
        'Missing dependencies: ${missingDependencyList.join(', ')}',
      )
      ..info('You can install them with')
      ..info(
        packageManager.printInstallDependenciesCommand(missingDependencyList),
        style: commandStyle,
      );
    exit(1);
  }

  logger.success('All dependencies are installed.\n');
}
