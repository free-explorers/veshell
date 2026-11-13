import 'package:shell/l10n/l10n.dart';

/// The power button actions, in the order shown in the picker. The value is
/// the settings string and matches `PowerButtonAction` in the compositor,
/// which handles the hardware power button: `sameAsIdle` follows
/// `idle.automaticPowerAction`.
const powerButtonActions = <String>[
  'sameAsIdle',
  'suspend',
  'hibernate',
  'suspendThenHibernate',
  'powerOff',
  'disabled',
];

/// The localized label for a power button action string.
String powerButtonActionLabel(AppLocalizations l10n, String value) =>
    switch (value) {
      'suspend' => l10n.sleep,
      'hibernate' => l10n.hibernate,
      'suspendThenHibernate' => l10n.powerButtonSuspendThenHibernate,
      'powerOff' => l10n.shutDown,
      'disabled' => l10n.powerButtonDoNothing,
      _ => l10n.powerButtonSameAsIdle,
    };
