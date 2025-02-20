import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/helm/control_panel/widget/control_panel.dart';
import 'package:shell/overview/helm/monitoring_panel/widget/monitoring_panel.dart';
import 'package:shell/overview/helm/notification_panel/widget/notification_panel.dart';

class Helm extends HookConsumerWidget {
  const Helm({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Row(
      children: [
        Expanded(child: ControlPanel()),
        SizedBox(width: 8),
        Expanded(child: MonitoringPanel()),
        SizedBox(width: 8),
        Expanded(child: NotificationPanel()),
      ],
    );
  }
}
