# Use the engine repository's nixpkgs, not the caller's channel, for release roots.
let
  nixpkgsRevision = "774debe7a0d1b496e35677ad955a1011c6ff74f3";
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsRevision}.tar.gz";
    sha256 = "1japvhk1jlgc8sihm9gczwnv6fjanqsr1ji57vx67wbvqj88a34x";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  basePackage = import ../default.nix { inherit pkgs; };
  shell = basePackage.shellBundle.overrideAttrs (old: {
    flutterBuildFlags = old.flutterBuildFlags ++ [ "--verbose" ];
  });
  package = basePackage.override { shellBundle = shell; };
  repository = import ./engine-repository.nix;
  enginePackages = pkgs.callPackage ./engine.nix { };
  rawEngine = enginePackages.engine;
  runtime = enginePackages.runtime;
  engine = package.flutterEngine;
in
assert pkgs.lib.assertMsg (engine ? sourceBuild)
  "Release distribution requires the source-engine adapter's sourceBuild passthru.";
assert pkgs.lib.assertMsg (engine.sourceBuild.drvPath == rawEngine.drvPath)
  "The package engine must be the exact independent source engine derivation.";
{
  inherit package engine rawEngine runtime nixpkgsRevision;
  engineSource = repository.source;
  engineSourceRevision = repository.revision;
  sdk = package.flutterSdk;
  inherit shell;
  aot = pkgs.callPackage ./engine-aot-test.nix { engine = rawEngine; inherit runtime; shellBundle = shell; };
}
