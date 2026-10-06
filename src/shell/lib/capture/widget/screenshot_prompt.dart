import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/capture/provider/screenshot_prompt.dart';
import 'package:shell/l10n/l10n.dart';

/// The trusted screenshot/color-pick prompt picker.
///
/// The prompt names the requesting application and the kind of capture;
/// it never shows pixel previews of what it is going to take. Allowing
/// reports the decision to the compositor, which takes the pixels in
/// Rust with no further shell involvement.
class ScreenshotPromptPicker extends ConsumerWidget {
  const ScreenshotPromptPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prompt = ref.watch(screenshotPromptProvider);

    if (prompt == null) {
      return const SizedBox.shrink();
    }
    final app = prompt.appName.isEmpty
        ? context.l10n.anApplication
        : prompt.appName;
    final request = switch (prompt.kind) {
      'color' => context.l10n.colorCaptureRequest(app),
      _ => context.l10n.screenshotRequest(app),
    };

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                context.l10n.allowCapture,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(request),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(screenshotPromptProvider.notifier).cancel(),
                    child: Text(context.l10n.deny),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.read(screenshotPromptProvider.notifier).approve(),
                    child: Text(context.l10n.allow),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Host for the screenshot prompt: identical blocking behavior to the
/// screen cast consent host.
class ScreenshotPromptHost extends ConsumerWidget {
  const ScreenshotPromptHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompt = ref.watch(screenshotPromptProvider);
    if (prompt == null) {
      return const SizedBox.shrink();
    }
    // The flow owns every input while it is open: the prompt is the only
    // thing that reacts until a decision is delivered.
    return Center(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Align(
          alignment: Alignment.center,
          child: ScreenshotPromptPicker(),
        ),
      ),
    );
  }
}
