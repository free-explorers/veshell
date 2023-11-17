import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/display/monitor/screen/workspace/tileable/persistent_application_launcher/app_drawer/app_drawer.dart';

class PersistentApplicationLauncher extends HookConsumerWidget {
  const PersistentApplicationLauncher({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppDrawer();
  }
}
