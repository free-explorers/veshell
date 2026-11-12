import 'package:shell/l10n/l10n.dart';

/// The Caps Lock behaviors, in the order shown in the picker. The value is the
/// settings string and matches `CapsLockBehavior` in the compositor, which
/// applies it as an xkb option on the seat keymap: both the shell and
/// forwarded clients see the remap.
const capsLockBehaviors = <String>[
  'default',
  'control',
  'escape',
  'swapescape',
  'disabled',
];

/// The localized label for a Caps Lock behavior string.
String capsLockLabel(AppLocalizations l10n, String value) => switch (value) {
  'control' => l10n.capsLockControl,
  'escape' => l10n.capsLockEscape,
  'swapescape' => l10n.capsLockSwapescape,
  'disabled' => l10n.capsLockDisabled,
  _ => l10n.capsLockDefault,
};

/// The keys that can start a compose sequence, in the order shown in the
/// picker. The value is the settings string and matches `ComposeKey` in the
/// compositor, which applies it as the xkb option `compose:<value>`.
const composeKeys = <String>[
  'none',
  'ralt',
  'rwin',
  'lwin',
  'menu',
  'rctrl',
  'lctrl',
  'caps',
  '102',
  'prsc',
  'sclk',
  'paus',
  'ins',
];

/// The localized label for a compose key string.
String composeKeyLabel(AppLocalizations l10n, String value) => switch (value) {
  'ralt' => l10n.composeKeyRightAlt,
  'rwin' => l10n.composeKeyRightWin,
  'lwin' => l10n.composeKeyLeftWin,
  'menu' => l10n.composeKeyMenu,
  'rctrl' => l10n.composeKeyRightCtrl,
  'lctrl' => l10n.composeKeyLeftCtrl,
  'caps' => l10n.capsLock,
  '102' => l10n.composeKeyLessGreater,
  'prsc' => l10n.composeKeyPrintScreen,
  'sclk' => l10n.composeKeyScrollLock,
  'paus' => l10n.composeKeyPause,
  'ins' => l10n.composeKeyInsert,
  _ => l10n.composeKeyNone,
};

/// The xkb options the dedicated Caps Lock and compose key settings own. The
/// options picker leaves them out so one remap has one place to set it.
final curatedKeyboardOptions = <String>{
  'ctrl:nocaps',
  'caps:escape',
  'caps:swapescape',
  'caps:none',
  for (final key in composeKeys)
    if (key != 'none') 'compose:$key',
};
