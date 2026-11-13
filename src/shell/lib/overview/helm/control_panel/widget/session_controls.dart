import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/systemd/provider/session.dart';
import 'package:shell/theme/provider/theme.dart';

class SessionControls extends HookConsumerWidget {
  const SessionControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boundsKey = useMemoized(GlobalKey.new);
    final availableActions =
        ref.watch(sessionControlAvailabilityProvider).value ?? {};
    if (availableActions.isEmpty) return const SizedBox.shrink();

    return Card(
      key: boundsKey,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (availableActions.contains(SessionControlAction.lock))
              Tooltip(
                message: context.l10n.lock,
                preferBelow: true,
                verticalOffset: 32,
                child: IconButton(
                  onPressed: () {
                    ref.read(sessionProvider.notifier).lock();
                  },
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const ShellIcon(MdiIcons.lock),
                ),
              ),
            if (availableActions.contains(SessionControlAction.logout))
              _ConfirmedSessionButton(
                boundsKey: boundsKey,
                icon: MdiIcons.logout,
                label: context.l10n.logOut,
                action: (session) => session.logout(),
              ),
            if (availableActions.contains(SessionControlAction.sleep))
              Tooltip(
                message: context.l10n.sleep,
                preferBelow: true,
                verticalOffset: 32,
                child: IconButton(
                  onPressed: () => _perform(
                    context,
                    ref,
                    context.l10n.sleep,
                    (session) => session.sleep(),
                  ),
                  icon: const ShellIcon(MdiIcons.powerSleep),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            if (availableActions.contains(SessionControlAction.hibernate))
              Tooltip(
                message: context.l10n.hibernate,
                preferBelow: true,
                verticalOffset: 32,
                child: IconButton(
                  onPressed: () async {
                    try {
                      await ref.read(sessionProvider.notifier).hibernate();
                    } catch (error) {
                      if (!context.mounted) return;
                      final message = error is StateError
                          ? error.message
                          : error;
                      await showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(context.l10n.unableToHibernate),
                          content: Text('$message'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(context.l10n.ok),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: const ShellIcon(MdiIcons.snowflake),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            if (availableActions.contains(SessionControlAction.reboot))
              _ConfirmedSessionButton(
                boundsKey: boundsKey,
                icon: MdiIcons.restart,
                label: context.l10n.reboot,
                action: (session) => session.reboot(),
              ),
            if (availableActions.contains(SessionControlAction.shutdown))
              _ConfirmedSessionButton(
                boundsKey: boundsKey,
                icon: MdiIcons.power,
                label: context.l10n.shutDown,
                action: (session) => session.shutdown(),
              ),
          ],
        ),
      ),
    );
  }
}

/// A session control that ends the session or the machine, so a stray click
/// must not lose work: it opens a small menu attached to the button, holding
/// only the labelled action, instead of acting at once. The menu sits above
/// the button (below when there is no room), centred on it but kept inside the
/// session controls card ([boundsKey]). The button stays highlighted while it
/// is open; the action takes the focus, so Enter confirms and Escape or a
/// click elsewhere cancels.
class _ConfirmedSessionButton extends HookConsumerWidget {
  const _ConfirmedSessionButton({
    required this.boundsKey,
    required this.icon,
    required this.label,
    required this.action,
  });

  final GlobalKey boundsKey;
  final IconData icon;
  final String label;
  final Future<void> Function(Session session) action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useMemoized(MenuController.new);
    final buttonFocusNode = useFocusNode(debugLabel: label);
    final confirmFocusNode = useFocusNode(debugLabel: '$label: confirm');

    return RawMenuAnchor(
      controller: controller,
      childFocusNode: buttonFocusNode,
      // The confirmation lives in an overlay, outside the overview's focus
      // scope, where `autofocus` would lose to the focus the overview already
      // holds: hand it the focus once it is built, and give it back to the
      // button when it closes.
      onOpen: () => WidgetsBinding.instance.addPostFrameCallback(
        (_) => confirmFocusNode.requestFocus(),
      ),
      onClose: () {
        if (confirmFocusNode.hasFocus || primaryFocus == null) {
          buttonFocusNode.requestFocus();
        }
      },
      overlayBuilder: (overlayContext, info) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        // Escape resolves to `DismissIntent`, which would otherwise bubble up
        // to the overview and hide it: here it only closes the confirmation.
        final popover = Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                controller.close();
                return null;
              },
            ),
          },
          child: TapRegion(
            groupId: info.tapRegionGroupId,
            onTapOutside: (_) => controller.close(),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.92 + 0.08 * value,
                  child: child,
                ),
              ),
              child: Material(
                color: colorScheme.surfaceContainerHigh,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(surfaceRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FilledButton.icon(
                    focusNode: confirmFocusNode,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    onPressed: () {
                      controller.close();
                      unawaited(_perform(context, ref, label, action));
                    },
                    icon: ShellIcon(icon, size: 18),
                    label: Text(label),
                  ),
                ),
              ),
            ),
          ),
        );
        return CustomSingleChildLayout(
          delegate: _ConfirmationLayout(
            anchor: info.anchorRect,
            bounds: _boundsIn(overlayContext) ?? Offset.zero & info.overlaySize,
          ),
          child: popover,
        );
      },
      builder: (context, controller, child) => Tooltip(
        message: label,
        preferBelow: true,
        verticalOffset: 32,
        child: IconButton(
          focusNode: buttonFocusNode,
          isSelected: controller.isOpen,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
          icon: ShellIcon(icon),
        ),
      ),
    );
  }

  /// The session controls card, in the coordinates of the overlay that shows
  /// the confirmation.
  Rect? _boundsIn(BuildContext overlayContext) {
    final bounds = boundsKey.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(overlayContext)?.context.findRenderObject();
    if (bounds is! RenderBox || overlay is! RenderBox) return null;
    return bounds.localToGlobal(Offset.zero, ancestor: overlay) & bounds.size;
  }
}

/// Places the confirmation [gap] above the [anchor] button, or below it when
/// it does not fit above, horizontally centred on it and clamped to [bounds].
class _ConfirmationLayout extends SingleChildLayoutDelegate {
  const _ConfirmationLayout({required this.anchor, required this.bounds});

  static const gap = 8.0;

  final Rect anchor;
  final Rect bounds;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = math.max(bounds.left, bounds.right - childSize.width);
    final left = (anchor.center.dx - childSize.width / 2).clamp(
      bounds.left,
      maxLeft,
    );
    final above = anchor.top - gap - childSize.height;
    final top = above >= 0 ? above : anchor.bottom + gap;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_ConfirmationLayout oldDelegate) =>
      anchor != oldDelegate.anchor || bounds != oldDelegate.bounds;
}

/// Runs a session [action], and says so when it fails (logind refused it, a
/// polkit denial, an instance isolated by veshell-probe, which may not act
/// on the host) instead of leaving the click without an answer.
Future<void> _perform(
  BuildContext context,
  WidgetRef ref,
  String label,
  Future<void> Function(Session session) action,
) async {
  try {
    await action(ref.read(sessionProvider.notifier));
  } on Object catch (error) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sessionActionFailed(label)),
        content: Text('$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }
}
