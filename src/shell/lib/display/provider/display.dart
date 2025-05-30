import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/model/display.dart';

part 'display.g.dart';

/// Provide the only Display to all his childrens
@riverpod
Display currentDisplay(Ref ref) {
  final viewSize =
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
  return Display(size: viewSize);
}
