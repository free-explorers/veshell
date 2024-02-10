import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme.manager.g.dart';

@riverpod
ThemeData Theme(ThemeRef ref) {
  const color = Color.fromARGB(255, 67, 76, 94);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: color,
    brightness: ThemeData.estimateBrightnessForColor(color),
  );
  return ThemeData(colorScheme: colorScheme, useMaterial3: true);
}
