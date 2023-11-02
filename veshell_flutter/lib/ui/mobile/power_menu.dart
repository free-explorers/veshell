import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/dbus/power_management.dart';
import 'package:zenith/ui/mobile/state/power_menu_state.dart';

class PowerMenu extends ConsumerWidget {
  const PowerMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(powerMenuStateNotifierProvider.select((v) => v.shown), (_, bool shown) {
      if (!shown) {
        ref.read(powerMenuStateNotifierProvider.notifier).removeOverlay();
      }
    });

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            ref.read(powerMenuStateNotifierProvider.notifier).hide();
          },
          child: Container(
            color: Colors.black26,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PowerButton(
                      icon: Icons.power_settings_new,
                      text: "Power off",
                      onPressed: () => powerOff(ref),
                    ),
                    const SizedBox(height: 40),
                    PowerButton(
                      icon: Icons.restart_alt,
                      text: "Restart",
                      onPressed: () => reboot(ref),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PowerButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  const PowerButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 40.0;
    const double padding = 40.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ink(
          decoration: const ShapeDecoration(
            color: Colors.white24,
            shape: CircleBorder(),
          ),
          child: IconButton(
            // padding: const EdgeInsets.all(50),
            iconSize: size,
            padding: const EdgeInsets.all(padding),
            splashRadius: (2 * padding + size) / 2,
            onPressed: onPressed,
            alignment: Alignment.center,
            icon: Icon(
              icon,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
