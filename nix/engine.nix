# Veshell selects the version and mode; the independent repository owns engine
# packaging. runtimeMode defaults to release, so the packaged build is unchanged;
# debug/profile are compiled on demand for development.
{ stdenv, runtimeMode ? "release", isOptimized ? runtimeMode != "debug" }:
let
  repository = import ./engine-repository.nix;
  flutterVersion = (builtins.fromTOML (builtins.readFile ../Cargo.toml)).package.metadata.flutter_version;
in
import repository.source {
  inherit flutterVersion runtimeMode isOptimized;
  system = stdenv.hostPlatform.system;
}
