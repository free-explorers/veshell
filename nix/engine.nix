# Veshell selects the version; the independent repository owns engine packaging.
{ stdenv }:
let
  repository = import ./engine-repository.nix;
  flutterVersion = (builtins.fromTOML (builtins.readFile ../Cargo.toml)).package.metadata.flutter_version;
in
import repository.source { inherit flutterVersion; system = stdenv.hostPlatform.system; }
