# Veshell selects the version and mode; flutter-engine-nix owns engine
# packaging. runtimeMode defaults to release, so the packaged build is unchanged;
# debug/profile are compiled on demand for development.
{
  stdenv,
  engineFor ? import ./engine-lock.nix,
  runtimeMode ? "release",
  isOptimized ? runtimeMode != "debug",
}:
engineFor {
  flutterVersion = (builtins.fromTOML (builtins.readFile ../Cargo.toml)).package.metadata.flutter_version;
  system = stdenv.hostPlatform.system;
  inherit runtimeMode isOptimized;
}
