import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/lookout/widget/lookout.dart';
import 'package:shell/shared/widget/clock.dart';

class Overview extends HookConsumerWidget {
  const Overview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      // Clip it cleanly.
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 16,
          sigmaY: 16,
        ),
        child: const ColoredBox(
          color: Colors.white12,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 32,
                child: ClockWidget(),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 64,
                  right: 64,
                  bottom: 64,
                  top: 96,
                ),
                child: Lookout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
