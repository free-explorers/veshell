import 'dart:io';

import 'package:path/path.dart' as path;

/// Common icon themes in fallback order.
///
/// Breeze comes before Adwaita because it ships the non-symbolic application
/// icons (for example `utilities-terminal`) that KDE applications request.
/// Adwaita often only provides their `-symbolic` variants, which do not match
/// the names in those `.desktop` files.
const _iconThemePreferences = ['breeze', 'Adwaita', 'hicolor'];

/// Common GTK themes in fallback order.
const _gtkThemePreferences = [
  'Adwaita-dark',
  'Breeze-Dark',
  'Adwaita',
  'Breeze',
];

/// The icon theme requested by GTK or KDE, if either desktop has been
/// configured. Veshell itself does not set one.
String? systemIconTheme({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final configDirectories = _configDirectories(env);

  for (final directory in configDirectories) {
    for (final variant in const ['gtk-4.0', 'gtk-3.0']) {
      final value = _readIniValue(
        path.join(directory, variant, 'settings.ini'),
        section: 'Settings',
        key: 'gtk-icon-theme-name',
      );
      if (value != null) return value;
    }
  }

  for (final directory in configDirectories) {
    final value = _readIniValue(
      path.join(directory, 'kdeglobals'),
      section: 'Icons',
      key: 'Theme',
    );
    if (value != null) return value;
  }

  return null;
}

/// The GTK theme requested by the environment or GTK configuration.
String? systemGtkTheme({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final fromEnvironment = env['GTK_THEME'];
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return fromEnvironment.split(':').first;
  }

  for (final directory in _configDirectories(env)) {
    for (final variant in const ['gtk-4.0', 'gtk-3.0']) {
      final value = _readIniValue(
        path.join(directory, variant, 'settings.ini'),
        section: 'Settings',
        key: 'gtk-theme-name',
      );
      if (value != null) return value;
    }
  }

  return null;
}

/// All icon themes installed in the standard XDG locations.
Set<String> installedIconThemes({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final themes = <String>{};

  for (final directory in _iconThemeDirectories(env)) {
    if (!Directory(directory).existsSync()) continue;
    for (final entity in Directory(directory).listSync()) {
      final name = path.basename(entity.path);
      if (name.endsWith('_cursors')) continue;
      if (File(path.join(entity.path, 'index.theme')).existsSync()) {
        themes.add(name);
      }
    }
  }

  return themes;
}

/// All GTK themes installed in the standard XDG locations.
Set<String> installedGtkThemes({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final themes = <String>{};

  for (final directory in _gtkThemeDirectories(env)) {
    if (!Directory(directory).existsSync()) continue;
    for (final entity in Directory(directory).listSync()) {
      final name = path.basename(entity.path);
      if (Directory(path.join(entity.path, 'gtk-3.0')).existsSync() ||
          Directory(path.join(entity.path, 'gtk-4.0')).existsSync()) {
        themes.add(name);
      }
    }
  }

  return themes;
}

/// Resolve the icon theme to use.
///
/// A configured value wins when it is installed. Otherwise the theme selected
/// by the surrounding desktop is used, then a complete common theme, then the
/// first installed theme. This keeps a stale or removed user override from
/// blanking every icon.
String chooseIconTheme(
  Set<String> installed, {
  String? configured,
  String? systemTheme,
}) {
  return _chooseTheme(
    installed,
    configured: configured,
    systemTheme: systemTheme,
    preferences: _iconThemePreferences,
    fallback: 'hicolor',
  );
}

/// Resolve the GTK theme to use.
String chooseGtkTheme(
  Set<String> installed, {
  String? configured,
  String? systemTheme,
}) {
  return _chooseTheme(
    installed,
    configured: configured,
    systemTheme: systemTheme,
    preferences: _gtkThemePreferences,
    fallback: 'Adwaita',
  );
}

/// Detect the icon theme for the current environment.
String detectIconTheme({Map<String, String>? environment}) {
  return chooseIconTheme(
    installedIconThemes(environment: environment),
    systemTheme: systemIconTheme(environment: environment),
  );
}

/// Detect the GTK theme for the current environment.
String detectGtkTheme({Map<String, String>? environment}) {
  return chooseGtkTheme(
    installedGtkThemes(environment: environment),
    systemTheme: systemGtkTheme(environment: environment),
  );
}

/// Fill absent theme values in the packaged defaults with detected ones.
///
/// The settings file only contains overrides. Keeping detection here, in the
/// defaults layer, means the merged settings expose a concrete value to the
/// settings UI while a user override still wins in `MergedSettingsJson`.
Map<String, dynamic> withDetectedThemeDefaults(
  Map<String, dynamic> settings, {
  String? iconTheme,
  String? gtkTheme,
}) {
  final theme = settings['theme'];
  if (theme is! Map) return settings;

  final resolvedTheme = Map<String, dynamic>.from(theme);
  if (resolvedTheme['iconTheme'] == null) {
    resolvedTheme['iconTheme'] = iconTheme ?? detectIconTheme();
  }
  if (resolvedTheme['gtkTheme'] == null) {
    resolvedTheme['gtkTheme'] = gtkTheme ?? detectGtkTheme();
  }

  return {...settings, 'theme': resolvedTheme};
}

String _chooseTheme(
  Set<String> installed, {
  required String? configured,
  required String? systemTheme,
  required List<String> preferences,
  required String fallback,
}) {
  final configuredMatch = _matchTheme(configured, installed);
  if (configuredMatch != null) return configuredMatch;

  final systemMatch = _matchTheme(systemTheme, installed);
  if (systemMatch != null) return systemMatch;

  for (final preference in preferences) {
    final match = _matchTheme(preference, installed);
    if (match != null) return match;
  }

  final remaining =
      installed.where((name) => !name.endsWith('_cursors')).toList()..sort();
  return remaining.isNotEmpty ? remaining.first : fallback;
}

String? _matchTheme(String? name, Set<String> installed) {
  if (name == null || name.isEmpty) return null;
  if (installed.contains(name)) return name;
  for (final candidate in installed) {
    if (candidate.toLowerCase() == name.toLowerCase()) return candidate;
  }
  return null;
}

List<String> _iconThemeDirectories(Map<String, String> env) {
  final directories = <String>[];
  final home = env['HOME'];
  if (home != null) directories.add(path.join(home, '.icons'));
  for (final dataDirectory in _dataDirectories(env)) {
    directories.add(path.join(dataDirectory, 'icons'));
  }
  return directories;
}

List<String> _gtkThemeDirectories(Map<String, String> env) {
  final directories = <String>[];
  final home = env['HOME'];
  if (home != null) directories.add(path.join(home, '.themes'));
  for (final dataDirectory in _dataDirectories(env)) {
    directories.add(path.join(dataDirectory, 'themes'));
  }
  return directories;
}

List<String> _dataDirectories(Map<String, String> env) {
  final directories = <String>[];
  final dataHome =
      env['XDG_DATA_HOME'] ??
      (env['HOME'] == null ? null : path.join(env['HOME']!, '.local', 'share'));
  if (dataHome != null) directories.add(dataHome);

  final dataDirs = env['XDG_DATA_DIRS'];
  if (dataDirs != null && dataDirs.isNotEmpty) {
    directories.addAll(_splitPath(dataDirs));
  } else {
    directories.addAll(const ['/usr/local/share', '/usr/share']);
  }
  return directories;
}

List<String> _configDirectories(Map<String, String> env) {
  final directories = <String>[];
  final configHome =
      env['XDG_CONFIG_HOME'] ??
      (env['HOME'] == null ? null : path.join(env['HOME']!, '.config'));
  if (configHome != null) directories.add(configHome);

  final configDirs = env['XDG_CONFIG_DIRS'];
  if (configDirs != null && configDirs.isNotEmpty) {
    directories.addAll(_splitPath(configDirs));
  } else {
    directories.add('/etc/xdg');
  }
  return directories;
}

Iterable<String> _splitPath(String value) =>
    value.split(':').where((directory) => directory.isNotEmpty);

String? _readIniValue(
  String filePath, {
  required String section,
  required String key,
}) {
  final file = File(filePath);
  if (!file.existsSync()) return null;

  String? currentSection;
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      currentSection = trimmed.substring(1, trimmed.length - 1).trim();
      continue;
    }
    if (currentSection != section) continue;

    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    if (trimmed.substring(0, separator).trim() != key) continue;
    return trimmed.substring(separator + 1).trim();
  }

  return null;
}
