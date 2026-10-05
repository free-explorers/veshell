# Instantiate nixpkgs' update helpers without changing the nixpkgs checkout.
# Pass pkgs.lib.fakeHash as lockHash or artifactHash to probe updated hashes.
{
  pkgs,
  lockHash ? null,
  artifactHash ? null,
  flutterPlatform ? "universal",
  systemPlatform ? pkgs.stdenv.hostPlatform.system,
}:
let
  version = (builtins.fromTOML (builtins.readFile ../Cargo.toml)).package.metadata.flutter_version;
  pin = (pkgs.lib.importJSON ./flutter-sdk.json).${version};
  flutterPath = pkgs.path + "/pkgs/development/compilers/flutter";
  source = pkgs.fetchFromGitHub {
    owner = "flutter";
    repo = "flutter";
    tag = version;
    hash = pin.flutterHash;
  };
  dart = pkgs.dart-bin.overrideAttrs (old: {
    version = pin.dartVersion;
    src = old.src.overrideAttrs (_: {
      hash = pin.dartHash.${pkgs.stdenv.hostPlatform.system};
    });
  });
  lockHelper = pkgs.writeText "get-flutter-pubspec-lock.nix" (
    builtins.replaceStrings
      [ "@flutter_compact_version@" "@flutter_src@" "@hash@" ]
      [ "veshell" source.outPath (if lockHash == null then pin.toolsLockHash else lockHash) ]
      (builtins.readFile (flutterPath + "/update/get-pubspec-lock.nix.in"))
  );
in
{
  inherit dart source;
  toolsLock = pkgs.callPackage lockHelper {
    flutterPackages.vveshell = { inherit dart; };
  };
  artifacts = pkgs.callPackage (flutterPath + "/artifacts/fetch-artifacts.nix") {
    flutter = (pkgs.callPackage ./flutter.nix { }).flutterSdk;
    inherit flutterPlatform systemPlatform;
    hash = if artifactHash == null then pin.artifactHashes.${flutterPlatform}.${systemPlatform} else artifactHash;
  };
}
