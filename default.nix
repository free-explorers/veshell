# pkgs builds the compositor, the process that loads the system's graphics
# driver; flutterPkgs builds the Flutter SDK and the shell bundle, which only
# need a nixpkgs whose Flutter packaging matches the pinned SDK. The engine
# always comes from flutter-engine-nix, whatever either of them is: engineFor
# is its lib.engineFor, at the revision flake.lock pins by default.
{
  pkgs ? import <nixpkgs> { },
  flutterPkgs ? pkgs,
  engineFor ? import ./nix/engine-lock.nix,
  buildCommit ? null,
  buildChannel ? null,
}:
let
  flutter = flutterPkgs.callPackage ./nix/flutter.nix { inherit engineFor; };
  dependencies = flutterPkgs.callPackage ./nix/dependencies.nix { };
  shellBundle = flutterPkgs.callPackage ./nix/shell.nix {
    inherit (flutter) flutterSdk flutterEngine;
    inherit (dependencies) pubspecLock gitHashes;
  };
in
pkgs.callPackage ./nix/package.nix {
  inherit (flutter) flutterSdk flutterEngine;
  inherit (dependencies) cargoHash;
  inherit shellBundle buildCommit buildChannel;
}
