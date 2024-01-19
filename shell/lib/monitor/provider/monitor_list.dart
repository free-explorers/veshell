import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/provider/display.dart';
import 'package:shell/monitor/model/monitor.dart';
import 'package:shell/monitor/provider/monitor_state.dart';
import 'package:uuid/uuid.dart';

part 'monitor_list.g.dart';

/// Provide list of plugged Monitors
@riverpod
List<Monitor> monitorList(MonitorListRef ref) {
  final display = ref.watch(currentDisplayProvider);
  return [
    Monitor(monitorId: const Uuid().v4(), surface: Offset.zero & display.size),
  ];
}
