import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme.manager.g.dart';

@riverpod
ThemeData Theme(ThemeRef ref) {
  const color = Colors.blue;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: color,
    brightness: ThemeData.estimateBrightnessForColor(color),
  );
  return ThemeData(colorScheme: colorScheme, useMaterial3: true);
}
