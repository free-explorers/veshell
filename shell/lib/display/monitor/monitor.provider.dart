import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:veshell/display/display.provider.dart';
import 'package:veshell/display/monitor/monitor.model.dart';

part 'monitor.provider.g.dart';

/// Provide the current Monitor to all his childrens
@Riverpod(dependencies: [])
Monitor currentMonitor(CurrentMonitorRef ref) {
  // This provider is instentatied in Children Scope
  throw Exception('Provider was not initialized');
}

/// Provide list of plugged Monitors
@riverpod
List<Monitor> monitorList(MonitorListRef ref) {
  final display = ref.watch(currentDisplayProvider);
  return [Monitor(surface: Offset.zero & display.size)];
}
