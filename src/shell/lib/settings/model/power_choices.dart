import 'package:shell/l10n/l10n.dart';

/// The power button actions, in the order shown in the picker. The value is
/// the settings string and matches `PowerButtonAction` in the compositor,
/// which handles the hardware power button. `suspendThenHibernate` is the
/// default, like `idle.automaticPowerAction`.
const powerButtonActions = <String>[
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
      'powerOff' => l10n.shutDown,
      'disabled' => l10n.powerButtonDoNothing,
      _ => l10n.powerButtonSuspendThenHibernate,
    };
