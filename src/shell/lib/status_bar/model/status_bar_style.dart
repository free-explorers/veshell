import 'package:shell/l10n/l10n.dart';

/// How the status bar is drawn, if at all. The enum names are the values
/// stored under `theme.statusBar`, in the order shown in the picker.
enum StatusBarStyle {
  /// No status bar. The default.
  none,

  /// A thin panel across the top of the workspaces, which it pushes down.
  topPanel,

  /// A notch hung from the top of the screen, right before the visible tile
  /// picker of the workspace panel, floating above the workspaces.
  notch,
}

/// The status bar styles, in the order shown in the picker.
final List<String> statusBarStyleChoices = [
  for (final style in StatusBarStyle.values) style.name,
];

/// The localized label for a status bar style setting string.
String statusBarStyleLabel(AppLocalizations l10n, String value) =>
    switch (StatusBarStyle.values.asNameMap()[value]) {
      StatusBarStyle.topPanel => l10n.statusBarTopPanel,
      StatusBarStyle.notch => l10n.statusBarNotch,
      _ => l10n.none,
    };
