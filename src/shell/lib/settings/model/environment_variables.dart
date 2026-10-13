/// Reads the `environment.variables` setting value as a name/value map.
///
/// The stored value is arbitrary JSON typed as `Map<String, dynamic>`; entries
/// that are not string-to-string are ignored so a hand-edited settings file
/// cannot crash the editor.
Map<String, String> environmentVariablesFromJson(dynamic value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}

/// Whether [name] is a valid environment variable name.
///
/// Portable POSIX name shape (`[A-Za-z_][A-Za-z0-9_]*`). It keeps the
/// `--setenv=NAME=value` forwarding unambiguous and rejects names that a shell
/// or the settings file would have to escape.
bool isEnvironmentVariableName(String name) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name);
