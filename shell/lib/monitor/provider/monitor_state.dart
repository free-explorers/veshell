import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/provider/display.dart';
import 'package:shell/monitor/model/monitor.dart';
import 'package:shell/monitor/provider/current_monitor.dart';
import 'package:shell/monitor/provider/monitor_list.dart';
import 'package:uuid/uuid.dart';

part 'monitor_state.g.dart';

/// Monitor provider
@riverpod
class MonitorState extends _$MonitorState {
  @override
  Monitor build(MonitorId monitorId) {
    final list = ref.watch(monitorListProvider);
    return list.firstWhere((element) => monitorId == element.monitorId);
  }
}
