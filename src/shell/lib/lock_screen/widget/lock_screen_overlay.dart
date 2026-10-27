import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/lock_screen/model/lock_screen_state/lock_screen_state.dart';
import 'package:shell/lock_screen/provider/lock_screen.dart';
import 'package:shell/monitor/provider/focused_monitor.dart';
import 'package:shell/shared/provider/now_date_time.dart';
import 'package:shell/shared/widget/frosted_surface.dart';

/// Blur of the locked desktop. Strong enough that window text cannot be read.
const _lockBlurSigma = 48.0;

/// Darkening veil over the blurred desktop, out of 255.
const _lockVeilAlpha = 110;

const _lockFadeDuration = Duration(milliseconds: 200);

/// Animation value of the lock: 0 unlocked, 1 fully locked.
///
/// Locking ramps in quickly; the overlay and the blur use the same timing, so
/// the prompt never shows over a sharp desktop.
double _useLockProgress(bool locked) {
  final controller = useAnimationController(
    duration: _lockFadeDuration,
    initialValue: locked ? 1 : 0,
  );
  useEffect(() {
    if (locked) {
      controller.forward();
    } else {
      controller.reverse();
    }
    return null;
  }, [locked]);
  return useAnimation(
    CurvedAnimation(parent: controller, curve: Curves.easeOut),
  );
}

/// Blurs and darkens a monitor's content while the session is locked, and
/// takes the keyboard away from it so no shell shortcut fires behind the
/// lock screen.
class LockScreenBlur extends HookConsumerWidget {
  /// Const constructor
  const LockScreenBlur({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(lockScreenProvider.select((s) => s.locked));
    final progress = _useLockProgress(locked);
    // The filters stay in the tree whatever the state: inserting a wrapper
    // would remount the whole desktop below it (see `FrostedSurface`).
    return ExcludeFocus(
      excluding: locked,
      child: FrostedSurface(
        blurSigma: _lockBlurSigma * progress,
        tint: progress > 0
            ? Colors.black.withAlpha((_lockVeilAlpha * progress).round())
            : null,
        tintOverContent: true,
        frame: false,
        highlight: false,
        noise: true,
        noiseOpacity: progress,
        child: child,
      ),
    );
  }
}

/// The lock screen drawn over a monitor: the clock everywhere, and the
/// password prompt on the focused monitor.
///
/// It swallows every pointer event while shown. The compositor already keeps
/// all input away from clients; this keeps it away from the shell below.
class LockScreenOverlay extends HookConsumerWidget {
  /// Const constructor
  const LockScreenOverlay({required this.monitorName, super.key});
  final String? monitorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(lockScreenProvider.select((s) => s.locked));
    final progress = _useLockProgress(locked);

    // Report the lock screen drawn once it is fully faded in, so a suspend
    // waiting for it goes ahead on a locked picture.
    final reported = useRef(false);
    useEffect(() {
      if (!locked) {
        reported.value = false;
      } else if (progress >= 1 && !reported.value) {
        reported.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(ref.read(lockScreenProvider.notifier).shown());
        });
      }
      return null;
    }, [locked, progress >= 1]);

    if (progress == 0) {
      return const SizedBox.shrink();
    }
    final isFocusedMonitor =
        monitorName != null &&
        ref.watch(focusedMonitorProvider.select((m) => m?.name)) == monitorName;

    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        // Opaque to hover too, so nothing below shows a hover state or
        // cursor.
        child: MouseRegion(
          // The overlay sits beside the Navigator, so it has neither the
          // `Material` the pages provide nor the Navigator's `Overlay`: the
          // text field and the tooltips need both.
          child: Material(
            type: MaterialType.transparency,
            child: Overlay.wrap(
              child: Opacity(
                opacity: progress,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _LockClock(),
                          const SizedBox(height: 48),
                          if (isFocusedMonitor && locked) const _UnlockPrompt(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockClock extends HookConsumerWidget {
  const _LockClock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useState(DateTime.now());
    ref.listen(nowDateTimeProvider, (prev, next) {
      if (prev?.minute != next.minute) now.value = next;
    });
    final locale = Localizations.localeOf(context).toString();
    final textTheme = Theme.of(context).textTheme;
    final shadow = [Shadow(color: Colors.black.withAlpha(90), blurRadius: 12)];
    return Column(
      children: [
        Text(
          DateFormat.jm(locale).format(now.value),
          style: textTheme.displayLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            shadows: shadow,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat.yMMMMEEEEd(locale).format(now.value),
          style: textTheme.titleLarge!.copyWith(
            color: Colors.white.withAlpha(220),
            shadows: shadow,
          ),
        ),
      ],
    );
  }
}

/// The user, the password field and the PAM messages.
class _UnlockPrompt extends HookConsumerWidget {
  const _UnlockPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockState = ref.watch(lockScreenProvider);
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    // Hidden by default, and again on every lock: the prompt is rebuilt from
    // scratch each time the session locks.
    final revealed = useState(false);
    final shake = useAnimationController(
      duration: const Duration(milliseconds: 400),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // The compositor queues an answer typed before PAM prompts (or after a
    // stack that ended without prompting), so the field takes input whenever
    // no attempt is being checked.
    final waiting = !lockState.checking;

    // Keep the keyboard on the field whenever it can take an answer.
    useEffect(() {
      if (waiting) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNode.context != null) focusNode.requestFocus();
        });
      }
      return null;
    }, [waiting]);

    // A failed attempt clears the field and shakes it.
    useEffect(() {
      if (lockState.failureCount > 0) {
        controller.clear();
        shake.forward(from: 0);
      }
      return null;
    }, [lockState.failureCount]);

    void submit() {
      if (!waiting) return;
      final response = controller.text;
      controller.clear();
      unawaited(ref.read(lockScreenProvider.notifier).submit(response));
    }

    final name = lockState.realName.isEmpty
        ? lockState.userName
        : lockState.realName;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              initial,
              style: textTheme.headlineMedium!.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: textTheme.titleLarge!.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                math.sin(shake.value * math.pi * 6) * 12 * (1 - shake.value),
                0,
              ),
              child: child,
            ),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape):
                    controller.clear,
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                readOnly: !waiting,
                obscureText: !lockState.echo && !revealed.value,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  filled: true,
                  hintText: _promptLabel(context, lockState),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A PAM prompt that asks for visible input (a user
                        // name) is already shown in clear.
                        if (!lockState.echo)
                          // Not focusable: clicking it must leave the
                          // keyboard on the field.
                          ExcludeFocus(
                            child: IconButton(
                              tooltip: revealed.value
                                  ? context.l10n.lockScreenHidePassword
                                  : context.l10n.lockScreenShowPassword,
                              onPressed: () => revealed.value = !revealed.value,
                              icon: Icon(
                                revealed.value
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        if (lockState.checking)
                          const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: context.l10n.lockScreenUnlock,
                            onPressed: waiting ? submit : null,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _NoticeLine(
            notice: lockState.passwordNotice,
            fallback: context.l10n.lockScreenWrongPassword,
          ),
          if (lockState.fingerprintNotice != null) ...[
            const SizedBox(height: 8),
            _NoticeLine(
              notice: lockState.fingerprintNotice,
              fallback: '',
              icon: MdiIcons.fingerprint,
            ),
          ],
        ],
      ),
    );
  }
}

/// PAM's prompt ("Password: ") as a field hint; our own label when PAM gives
/// none yet.
String _promptLabel(BuildContext context, LockScreenState state) {
  if (state.checking) return context.l10n.lockScreenChecking;
  final prompt = state.prompt?.trim().replaceFirst(RegExp(r':$'), '').trim();
  if (prompt == null || prompt.isEmpty) return context.l10n.lockScreenPassword;
  return prompt;
}

class _NoticeLine extends StatelessWidget {
  const _NoticeLine({required this.notice, required this.fallback, this.icon});
  final LockScreenNotice? notice;
  final String fallback;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final notice = this.notice;
    if (notice == null) return const SizedBox(height: 20);
    final text = notice.text ?? fallback;
    if (text.isEmpty) return const SizedBox(height: 20);
    final color = notice.isError
        ? Theme.of(context).colorScheme.error
        : Colors.white.withAlpha(220);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
