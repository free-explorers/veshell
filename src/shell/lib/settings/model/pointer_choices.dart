import 'package:shell/l10n/l10n.dart';

/// The pointer acceleration profiles, in the order shown in the picker. The
/// value is the settings string and matches `AccelerationProfile` in the
/// compositor, which applies it to each libinput mouse or touchpad: `default`
/// keeps the device's own libinput default (adaptive for most devices).
const accelerationProfiles = <String>['default', 'adaptive', 'flat'];

/// The localized label for an acceleration profile string.
String accelerationProfileLabel(AppLocalizations l10n, String value) =>
    switch (value) {
      'adaptive' => l10n.accelerationProfileAdaptive,
      'flat' => l10n.accelerationProfileFlat,
      _ => l10n.accelerationProfileDefault,
    };
