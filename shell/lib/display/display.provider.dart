import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/display.model.dart';

part 'display.provider.g.dart';

/// Provide the only Display to all his childrens
@riverpod
Display currentDisplay(CurrentDisplayRef ref) {
  final viewSize =
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
  return Display(size: viewSize);
}
