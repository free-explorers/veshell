import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/display/monitor/screen/screen.provider.dart';
import 'package:veshell/display/monitor/screen/screen.widget.dart';

/// Widget that represent the Monitor in the widget tree
class MonitorWidget extends HookConsumerWidget {
  /// Const constructor
  const MonitorWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenList = ref.watch(screenListProvider);
    return Stack(
      children: [
        for (final screen in screenList)
          ProviderScope(
            overrides: [currentScreenProvider.overrideWith((ref) => screen)],
            child: const ScreenWidget(),
          ),
      ],
    );
  }
}
