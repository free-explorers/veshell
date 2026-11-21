import 'package:shell/l10n/l10n.dart';

/// The antialiasing choices, in the order shown in the picker. The value is
/// the settings string and matches `Antialiasing` in the compositor, which
/// multisamples the shell's rendering.
const antialiasingChoices = <String>['auto', 'off', '2x', '4x'];

/// The default antialiasing: chosen by the GPU.
const antialiasingFallback = 'auto';

/// The localized label for an antialiasing string. The sample counts read the
/// same in every language.
String antialiasingLabel(AppLocalizations l10n, String value) =>
    switch (value) {
      'off' => l10n.antialiasingOff,
      '2x' => '2×',
      '4x' => '4×',
      _ => l10n.antialiasingAuto,
    };
