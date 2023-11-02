import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/enums.dart';
import 'package:zenith/platform_api.dart';
import 'package:zenith/ui/mobile/state/mobile_lock_screen_widget_state.dart';
import 'package:zenith/util/state/lock_screen_state.dart';
import 'package:zenith/util/state/screen_state.dart';

part '../../generated/ui/mobile/lock_screen.g.dart';

@Riverpod(keepAlive: true)
class _AuthErrorMessage extends _$AuthErrorMessage {
  @override
  String build() => "";
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> with TickerProviderStateMixin {
  late AnimationController _showAuthenticationAnimationController;
  Animation<double>? _slideAnimation;

  late final AnimationController _unlockFadeAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final Animation<double> _unlockFadeAnimation = Tween(
    begin: 1.0,
    end: 0.0,
  ).animate(_unlockFadeAnimationController);

  @override
  void initState() {
    super.initState();
    _showAuthenticationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      // Duration is irrelevant because of .fling().
      vsync: this,
    );
  }

  @override
  void dispose() {
    _showAuthenticationAnimationController.dispose();
    super.dispose();
  }

  void _updateOffset() {
    ref.read(mobileLockScreenStateProvider.notifier).offset = _slideAnimation!.value;
  }

  @override
  Widget build(BuildContext context) {
    _registerListeners();

    return Consumer(
      builder: (_, WidgetRef ref, Widget? child) {
        // Ignore tap events during unlock animation.
        bool locked = ref.watch(lockScreenStateProvider.select((value) => value.locked));
        return IgnorePointer(
          ignoring: !locked,
          child: child,
        );
      },
      child: FadeTransition(
        opacity: _unlockFadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset("assets/images/background.jpg", fit: BoxFit.cover),
            Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final offset = ref.watch(mobileLockScreenStateProvider.select((v) => v.offset));
                final slideDistance = ref.watch(mobileLockScreenStateProvider.select((v) => v.slideDistance));
                double progression = offset / slideDistance;

                const double maxBlurAmount = 30;
                double blurAmount = progression <= 0.5 ? 0 : maxBlurAmount * 2 * (progression - 0.5);

                return BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurAmount,
                    sigmaY: blurAmount,
                  ),
                  child: child,
                );
              },
              child: const ClockAndPinAuthenticationStack(),
            ),
            GestureDetector(
              onPanStart: (DragStartDetails details) {
                ref.read(mobileLockScreenStateProvider.notifier).startDrag();
              },
              onPanUpdate: (DragUpdateDetails details) {
                ref.read(mobileLockScreenStateProvider.notifier).drag(-details.delta.dy);
              },
              onPanEnd: (DragEndDetails details) {
                ref.read(mobileLockScreenStateProvider.notifier).endDrag(details.velocity.pixelsPerSecond.dy);
              },
            )
          ],
        ),
      ),
    );
  }

  void _registerListeners() {
    ref.listen(mobileLockScreenStateProvider.select((v) => v.dragging), (_, bool dragging) {
      MobileLockScreenWidgetState state = ref.read(mobileLockScreenStateProvider);
      double velocity = state.dragVelocity;

      if (dragging) {
        _showAuthenticationAnimationController.stop();
      } else {
        _slideAnimation?.removeListener(_updateOffset);

        if (velocity.abs() > 300) {
          if (velocity.isNegative) {
            _slideAnimation = Tween(
              begin: state.offset,
              end: state.slideDistance,
            ).animate(_showAuthenticationAnimationController);
          } else {
            _slideAnimation = Tween(
              begin: state.offset,
              end: 0.0,
            ).animate(_showAuthenticationAnimationController);
          }
        } else {
          double progression = state.offset / state.slideDistance;
          if (progression >= 0.5) {
            _slideAnimation = Tween(
              begin: state.offset,
              end: state.slideDistance,
            ).animate(_showAuthenticationAnimationController);
          } else {
            _slideAnimation = Tween(
              begin: state.offset,
              end: 0.0,
            ).animate(_showAuthenticationAnimationController);
          }
        }
        _slideAnimation!.addListener(_updateOffset);
        _showAuthenticationAnimationController
          ..reset()
          ..fling(velocity: velocity.abs() / 50);
      }
    });

    ref.listen(lockScreenStateProvider.select((v) => v.locked), (_, bool locked) {
      if (!locked) {
        _unlockFadeAnimationController.forward().whenComplete(() {
          ref.read(mobileLockScreenStateProvider.notifier).removeOverlay();
        });
      } else {
        _unlockFadeAnimationController.reset();
      }
    });
  }
}

class ClockAndPinAuthenticationStack extends ConsumerWidget {
  const ClockAndPinAuthenticationStack({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double offset = ref.watch(mobileLockScreenStateProvider.select((v) => v.offset));
    double slideDistance = ref.watch(mobileLockScreenStateProvider.select((v) => v.slideDistance));
    double progression = offset / slideDistance;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: progression >= 0.5,
          child: Transform.translate(
            offset: Offset(0, -offset),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => ref.read(screenStateNotifierProvider.notifier).turnOff(),
              child: Opacity(
                opacity: (1.0 - offset / (slideDistance / 2)).clamp(0.0, 1.0),
                child: const Clock(),
              ),
            ),
          ),
        ),
        IgnorePointer(
          ignoring: progression < 0.5,
          child: Transform.translate(
            offset: Offset(0, slideDistance - offset),
            child: Opacity(
              opacity: (offset / (slideDistance / 2) - 1.0).clamp(0.0, 1.0),
              child: const PinAuthentication(),
            ),
          ),
        ),
      ],
    );
  }
}

const _shadow = Shadow(
  color: Colors.black45,
  blurRadius: 10,
);

class Clock extends StatefulWidget {
  const Clock({super.key});

  @override
  State<Clock> createState() => _ClockState();
}

class _ClockState extends State<Clock> {
  final DateFormat _format = DateFormat.MMMMEEEEd();
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Stack(
      children: [
        Align(
          alignment: const Alignment(0, -0.8),
          child: Text(
            _format.format(now),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              shadows: [_shadow],
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: DefaultTextStyle(
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 180,
              fontWeight: FontWeight.normal,
              height: 0.8,
              shadows: [_shadow],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${now.hour}".padLeft(2, '0')),
                Text("${now.minute}".padLeft(2, '0')),
              ],
            ),
          ),
        ),
        const Align(
          alignment: Alignment(0, 0.7),
          child: Icon(
            Icons.lock,
            color: Colors.white,
            size: 50,
            shadows: [_shadow],
          ),
        ),
      ],
    );
  }
}

class PinAuthentication extends ConsumerStatefulWidget {
  const PinAuthentication({super.key});

  @override
  ConsumerState<PinAuthentication> createState() => _PinAuthenticationState();
}

class _PinAuthenticationState extends ConsumerState<PinAuthentication> {
  late TextEditingController _pinTextController;

  @override
  void initState() {
    super.initState();
    _pinTextController = TextEditingController();
  }

  @override
  void dispose() {
    _pinTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lockScreenStateProvider.select((v) => v.lock), (_, __) {
      _pinTextController.clear();
    });

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Align(
            alignment: Alignment(0, -0.85),
            child: AuthErrorMessage(),
          ),
          Align(
            alignment: const Alignment(0, -0.7),
            child: PinText(controller: _pinTextController),
          ),
          Align(
            alignment: const Alignment(0, 0.8),
            child: KeyPad(controller: _pinTextController),
          ),
        ],
      ),
    );
  }
}

class AuthErrorMessage extends ConsumerWidget {
  const AuthErrorMessage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      ref.watch(_authErrorMessageProvider),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        shadows: [_shadow],
      ),
    );
  }
}

class PinText extends StatelessWidget {
  final TextEditingController controller;

  const PinText({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? child) {
        return Wrap(
          alignment: WrapAlignment.center,
          children: List<Widget>.filled(
            value.text.length,
            const Text(
              "●",
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                shadows: [Shadow(color: Colors.black45, blurRadius: 5)],
              ),
            ),
          ).interleave(const SizedBox(width: 20)).toList(),
        );
      },
    );
  }
}

class KeyPad extends ConsumerWidget {
  final TextEditingController controller;

  const KeyPad({super.key, required this.controller});

  void authenticate(WidgetRef ref) async {
    AuthenticationResponse response = await ref.read(platformApiProvider.notifier).unlockSession(controller.text);

    if (!response.success) {
      controller.clear();
      ref.read(_authErrorMessageProvider.notifier).state = response.message.isNotEmpty ? response.message : "Wrong PIN";
    } else {
      ref.read(lockScreenStateProvider.notifier).unlock();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void enterDigit(String digit) {
      controller.text += digit;
      ref.read(_authErrorMessageProvider.notifier).state = "";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinButton(child: const Text("1"), onTap: () => enterDigit("1")),
            PinButton(child: const Text("2"), onTap: () => enterDigit("2")),
            PinButton(child: const Text("3"), onTap: () => enterDigit("3")),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinButton(child: const Text("4"), onTap: () => enterDigit("4")),
            PinButton(child: const Text("5"), onTap: () => enterDigit("5")),
            PinButton(child: const Text("6"), onTap: () => enterDigit("6")),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinButton(child: const Text("7"), onTap: () => enterDigit("7")),
            PinButton(child: const Text("8"), onTap: () => enterDigit("8")),
            PinButton(child: const Text("9"), onTap: () => enterDigit("9")),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PinButton(
              onTap: () {
                if (controller.text.isNotEmpty) {
                  controller.text = controller.text.substring(0, controller.text.length - 1);
                }
              },
              onLongPress: () => controller.clear(),
              child: const Icon(Icons.backspace, color: Colors.white),
            ),
            PinButton(child: const Text("0"), onTap: () => enterDigit("0")),
            PinButton(
              onTap: () => authenticate(ref),
              child: const Icon(Icons.check, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

class PinButton extends StatelessWidget {
  const PinButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: SizedBox.fromSize(
        size: const Size(80, 80),
        child: ClipOval(
          child: Material(
            color: Colors.white12,
            child: InkWell(
              splashColor: Colors.white24,
              onTap: onTap,
              onLongPress: onLongPress,
              child: Center(
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
