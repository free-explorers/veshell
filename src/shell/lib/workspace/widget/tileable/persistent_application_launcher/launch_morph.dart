import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show lerpDouble;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/widget/window_placeholder.dart';
import 'package:shell/workspace/model/launch_morph_request.dart';
import 'package:shell/workspace/provider/launch_morphs.dart';

export 'package:shell/workspace/model/launch_morph_request.dart'
    show LaunchMorphRequest, LaunchOrigin;

/// How long a launcher item takes to become the launched tile's placeholder.
const launchMorphDuration = Duration(milliseconds: 450);

/// The corner radius of a launcher item, where the card starts.
const _itemRadius = 24.0;

/// Where the placeholder's parts sit, in the morph's coordinates.
typedef _Landing = ({ui.Rect card, ui.Rect icon, ui.Rect title});

/// Opens a tile launched from the tiled launcher: the launched item morphs
/// into the tile's placeholder.
///
/// It plays in the new tile, over its placeholder (which the tile keeps
/// unpainted meanwhile), and ends exactly as the placeholder looks once the
/// tile has the keyboard. The tile takes the launcher's place (the launcher
/// moves aside, it is never shown twice), so the morph starts from where the
/// item was ([LaunchMorphRequest.origin]):
///
/// - the item, as a card of the launcher's card color, grows into the
///   placeholder's centered card (its rect, corners and translucent color);
/// - its icon and label travel to the placeholder's icon and title, the small
///   label giving way to the title along the way;
/// - the rest of the card's content fades in at its place;
/// - behind it, the blurred icon backdrop fades in.
///
/// The backdrop and the card's content are drawn by [WindowPlaceholder]
/// layers laid out at the tile's size from the start, which is also where the
/// landing places are measured. [onDone] is called once the morph has landed.
class LaunchMorph extends HookConsumerWidget {
  const LaunchMorph({
    required this.window,
    required this.request,
    required this.onDone,
    super.key,
  });

  /// The launched tile's window.
  final PersistentWindow window;

  final LaunchMorphRequest request;

  final VoidCallback onDone;

  /// The flying card, icon and title.
  @visibleForTesting
  static const ValueKey<String> flyingCardKey = ValueKey('launch-morph-card');
  @visibleForTesting
  static const ValueKey<String> flyingIconKey = ValueKey('launch-morph-icon');
  @visibleForTesting
  static const ValueKey<String> flyingTitleKey = ValueKey('launch-morph-title');

  static const Curve _move = Curves.easeInOutCubicEmphasized;
  static const Curve _backdropIn = Interval(0, 0.6, curve: Curves.easeInOut);

  /// The card stays opaque until the backdrop is in: only then may it turn
  /// translucent, showing the backdrop rather than the launcher behind it.
  static const Curve _cardClears = Interval(0.6, 1, curve: Curves.easeInOut);
  static const Curve _contentIn = Interval(0.45, 1, curve: Curves.easeOut);
  static const Curve _iconSwap = Interval(0.15, 0.75, curve: Curves.easeInOut);
  static const Curve _titleSwap = Interval(0.1, 0.65, curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useAnimationController(duration: launchMorphDuration);
    final rootKey = useMemoized(GlobalKey.new);
    final cardKey = useMemoized(GlobalKey.new);
    final iconKey = useMemoized(GlobalKey.new);
    final titleKey = useMemoized(GlobalKey.new);
    final landing = useState<_Landing?>(null);

    final entry = request.entry;
    final appId = window.properties.appId;
    final name = entry.entries[DesktopEntryKey.name.string] ?? '';
    final iconPath = entry.entries[DesktopEntryKey.icon.string];
    // The tile sits where the launcher was: the launch's places, global,
    // shift into the tile by the launcher's corner.
    final shift = -request.launcherRect.topLeft;
    final origin = (
      item: request.origin.item.shift(shift),
      icon: request.origin.icon.shift(shift),
      label: request.origin.label.shift(shift),
    );

    // A tile closed mid-morph abandons it. Deferred: providers must not change
    // while the tree is finalized.
    final morphs = ref.read(launchMorphsProvider.notifier);
    final windowId = window.windowId;
    useEffect(
      () =>
          () => Future.microtask(() => morphs.finish(windowId)),
      [windowId],
    );

    // The placeholder lays its card out around its desktop entry (the command
    // line, notably, which can be long): measured before the entry has
    // loaded, the icon and title would move after the morph had aimed at
    // them. The morph waits for it; the card holds on the item meanwhile.
    final entryLoaded = ref.watch(
      localizedDesktopEntryForIdProvider(appId).select((v) => !v.isLoading),
    );

    _Landing? measure() {
      final root = rootKey.currentContext?.findRenderObject() as RenderBox?;
      Rect? rectOf(GlobalKey key) {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        if (root == null || box == null || !box.hasSize) {
          return null;
        }
        return box.localToGlobal(Offset.zero, ancestor: root) & box.size;
      }

      final card = rectOf(cardKey);
      final icon = rectOf(iconKey);
      final title = rectOf(titleKey);
      if (card == null || icon == null || title == null) {
        return null;
      }
      return (card: card, icon: icon, title: title);
    }

    // Measured after the placeholder's layout once the entry is in, then the
    // morph starts.
    useEffect(() {
      if (!entryLoaded) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || landing.value != null) {
          return;
        }
        final measured = measure();
        if (measured == null) {
          // Nothing to land on: hand over at once.
          onDone();
          return;
        }
        landing.value = measured;
        unawaited(
          controller.forward().whenComplete(() {
            if (context.mounted) {
              onDone();
            }
          }),
        );
      });
      return null;
    }, [entryLoaded]);

    // Should the placeholder still change its layout (an icon or a font that
    // arrives late), the landing follows it, a frame behind, instead of the
    // morph ending off its target.
    useEffect(() {
      var scheduled = false;
      void remeasure() {
        if (scheduled) {
          return;
        }
        scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scheduled = false;
          final current = landing.value;
          final measured = context.mounted ? measure() : null;
          if (current != null && measured != null && measured != current) {
            landing.value = measured;
          }
        });
      }

      controller.addListener(remeasure);
      return () => controller.removeListener(remeasure);
    }, [controller]);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // The item lifts out in the color of the launcher's card, and lands in the
    // placeholder card's, as the tile shows it once it has the keyboard.
    final launcherCardColor =
        theme.cardTheme.color ?? colorScheme.surfaceContainerLow;
    final placeholderCardColor = colorScheme.surface.withAlpha(
      placeholderCardAlpha,
    );
    final cardRadius = switch (theme.cardTheme.shape) {
      RoundedRectangleBorder(:final BorderRadius borderRadius) =>
        borderRadius.topLeft.x,
      _ => 12.0,
    };
    final labelStyle = theme.textTheme.bodyMedium;
    final titleStyle = theme.textTheme.displayMedium;

    Widget placeholderPart(PlaceholderPart part) => WindowPlaceholder(
      isSelected: true,
      window: window,
      part: part,
      displayFocused: true,
      cardKey: part == PlaceholderPart.cardContent ? cardKey : null,
      iconKey: part == PlaceholderPart.cardContent ? iconKey : null,
      titleKey: part == PlaceholderPart.cardContent ? titleKey : null,
    );
    final backdrop = placeholderPart(PlaceholderPart.background);
    final content = placeholderPart(PlaceholderPart.cardContent);

    return IgnorePointer(
      // Rendered for its looks only: it must not take the keyboard (the
      // placeholder autofocuses) nor the pointer.
      child: ExcludeFocus(
        child: AnimatedBuilder(
          key: rootKey,
          animation: controller,
          builder: (context, _) {
            final progress = controller.value;
            final t = _move.transform(progress);
            final target = landing.value;

            final cardRect = target == null
                ? origin.item
                : Rect.lerp(origin.item, target.card, t)!;
            final card = RRect.fromRectAndRadius(
              cardRect,
              Radius.circular(lerpDouble(_itemRadius, cardRadius, t)!),
            );
            // Lifted: the shadow rises as the card leaves and settles as it
            // lands (the placeholder's card has none).
            final lift = math.sin(math.pi * t);
            // The parts inside the card: the focused card is fully opaque.
            const partOpacity = 1.0;

            final iconRect = target == null
                ? origin.icon
                : Rect.lerp(origin.icon, target.icon, t)!;
            final iconSwap = target == null
                ? 0.0
                : _iconSwap.transform(progress);
            final titleSwap = target == null
                ? 0.0
                : _titleSwap.transform(progress);
            // The label and the title share one path, each keeping its own
            // proportions: the label grows into the title as they cross.
            Rect textRect(double aspect) {
              if (target == null) {
                return Rect.fromCenter(
                  center: origin.label.center,
                  width: origin.label.height * aspect,
                  height: origin.label.height,
                );
              }
              final height = lerpDouble(
                origin.label.height,
                target.title.height,
                t,
              )!;
              return Rect.fromCenter(
                center: Offset.lerp(
                  origin.label.center,
                  target.title.center,
                  t,
                )!,
                width: height * aspect,
                height: height,
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: target == null ? 0 : _backdropIn.transform(progress),
                  child: backdrop,
                ),
                Positioned.fromRect(
                  key: flyingCardKey,
                  rect: cardRect,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: Color.lerp(
                        launcherCardColor,
                        placeholderCardColor,
                        target == null ? 0 : _cardClears.transform(progress),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(card.tlRadius),
                      ),
                      shadows: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(
                            alpha: 0.3 * lift,
                          ),
                          blurRadius: 24 * lift,
                          offset: Offset(0, 8 * lift),
                        ),
                      ],
                    ),
                  ),
                ),
                // The rest of the card's content, at its place, shows inside
                // the growing card.
                ClipRRect(
                  clipper: _RRectClipper(card),
                  child: Opacity(
                    opacity: target == null
                        ? 0
                        : _contentIn.transform(progress),
                    child: content,
                  ),
                ),
                Positioned.fromRect(
                  key: flyingIconKey,
                  rect: iconRect,
                  child: Opacity(
                    opacity: partOpacity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // The item's icon, at the size it is decoded at…
                        Opacity(
                          opacity: 1 - iconSwap,
                          child: FittedBox(
                            child: SizedBox.fromSize(
                              size: origin.icon.size,
                              child: AppIconByPath(path: iconPath, title: name),
                            ),
                          ),
                        ),
                        // …gives way to the placeholder's, at its own.
                        if (target != null)
                          Opacity(
                            opacity: iconSwap,
                            child: FittedBox(
                              child: SizedBox.fromSize(
                                size: target.icon.size,
                                child: AppIconById(id: appId),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: textRect(origin.label.width / origin.label.height),
                  child: Opacity(
                    opacity: partOpacity * (1 - titleSwap),
                    child: FittedBox(
                      child: SizedBox.fromSize(
                        size: origin.label.size,
                        child: Text(
                          name,
                          style: labelStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                if (target != null)
                  Positioned.fromRect(
                    key: flyingTitleKey,
                    rect: textRect(target.title.width / target.title.height),
                    child: Opacity(
                      opacity: partOpacity * titleSwap,
                      child: FittedBox(
                        child: SizedBox.fromSize(
                          size: target.title.size,
                          child: Text(
                            name,
                            style: titleStyle,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RRectClipper extends CustomClipper<RRect> {
  const _RRectClipper(this.rrect);

  final RRect rrect;

  @override
  RRect getClip(Size size) => rrect;

  @override
  bool shouldReclip(_RRectClipper oldClipper) => oldClipper.rrect != rrect;
}
