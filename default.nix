{ pkgs ? import <nixpkgs> { } }:
let
  flutter = pkgs.callPackage ./nix/flutter.nix { };
  dependencies = pkgs.callPackage ./nix/dependencies.nix { };
  shellBundle = pkgs.callPackage ./nix/shell.nix {
    inherit (flutter) flutterSdk;
    inherit (dependencies) pubspecLock gitHashes;
  };
in
pkgs.callPackage ./nix/package.nix {
  inherit (flutter) flutterSdk flutterEngine;
  inherit (dependencies) cargoHash;
  inherit shellBundle;
}
