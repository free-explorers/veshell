import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/display.provider.dart';
import 'package:shell/display/monitor/monitor.model.dart';
import 'package:uuid/uuid.dart';

part 'monitor.provider.g.dart';

/// Provide the current Monitor to all his childrens
@Riverpod(dependencies: [])
MonitorId currentMonitor(CurrentMonitorRef ref) {
  // This provider is instentatied in Children Scope
  throw Exception('Provider was not initialized');
}

/// Provide list of plugged Monitors
@riverpod
List<Monitor> monitorList(MonitorListRef ref) {
  final display = ref.watch(currentDisplayProvider);
  return [
    Monitor(monitorId: const Uuid().v4(), surface: Offset.zero & display.size),
  ];
}

/// Monitor provider
@riverpod
class MonitorState extends _$MonitorState {
  @override
  Monitor build(MonitorId monitorId) {
    final list = ref.watch(monitorListProvider);
    return list.firstWhere((element) => monitorId == element.monitorId);
  }
}
