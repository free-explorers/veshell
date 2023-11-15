/// DISPLAY
/// The digital world of Veshell, the root component that contain everything else. It's span accross all monitor.

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

part 'display.freezed.dart';


@freezed
abstract class DisplayState with _$DisplayState{
  const factory DisplayState() = _DisplayState;
}

class Display extends HookConsumerWidget {
  const Display({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container();
  }
}

/* class Display extends InheritedWidget {
  const Display({
    super.key,
    required super.child,
  });

  static Display? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<Display>();
  }

  static Display of(BuildContext context) {
    final Display? result = maybeOf(context);
    assert(result != null, 'No Display found in context');
    return result!;
  }
  
  build(BuildContext context) {
    return child;
  }

  @override
  bool updateShouldNotify(Display oldWidget) => false;
} */

