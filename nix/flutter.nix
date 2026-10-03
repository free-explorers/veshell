# Returns { flutterSdk, flutterEngine, engineVersion, version }.
# sdkData, when supplied, is verified nixpkgs mkFlutter metadata, including
# version, engineVersion, flutterHash, dartVersion, dartHash, pubspecLock,
# artifactHashes (universal and linux), and channel.
# Rebuild metadata with flutter-sdk-update.nix when the Cargo.toml pin changes.
{
  lib,
  callPackage,
  path,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  libGL,
  sdkData ? null,
}:
let
  version = (builtins.fromTOML (builtins.readFile ../Cargo.toml)).package.metadata.flutter_version;
  pins = lib.importJSON ./flutter-sdk.json;
  pin = pins.${version} or (throw "No verified Flutter SDK/engine metadata for Cargo.toml pin ${version}.");
  inherit (pin) engineVersion;
  system = stdenv.hostPlatform.system;
  arch = {
    x86_64-linux = "x86_64";
    aarch64-linux = "arm64";
  }.${system} or (throw "Veshell's prebuilt Flutter engine does not support ${system}.");
  flutterPath = path + "/pkgs/development/compilers/flutter";
  flutterPackages = callPackage (flutterPath + "/default.nix") {
    useNixpkgsEngine = false;
  };
  patchDir = flutterPath + "/patches";
  # In this SDK, Linux host detection moved from _PosixUtils to the base class.
  hostPlatformPatch = builtins.toFile "flutter-nix-host-platform.patch" ''
    --- a/packages/flutter_tools/lib/src/base/os.dart
    +++ b/packages/flutter_tools/lib/src/base/os.dart
    @@ -146,6 +146,13 @@
       /// Represents the platform of the host machine running the Flutter tool.
       HostPlatform get hostPlatform {
    +    const nixHost = String.fromEnvironment('NIX_FLUTTER_HOST_PLATFORM');
    +    if (nixHost == 'x86_64-linux') {
    +      return HostPlatform.linux_x64;
    +    }
    +    if (nixHost == 'aarch64-linux') {
    +      return HostPlatform.linux_arm64;
    +    }
         return switch (_currentAbi) {
           Abi.macosX64 => HostPlatform.darwin_x64,
           Abi.macosArm64 => HostPlatform.darwin_arm64,
           Abi.linuxX64 => HostPlatform.linux_x64,
  '';
  defaultSdkData = {
    inherit version engineVersion;
    inherit (pin) flutterHash dartVersion dartHash artifactHashes;
    channel = "stable";
    pubspecLock = lib.importJSON ./flutter-tools-lock.json;
  };
  data = if sdkData == null then defaultSdkData else sdkData;
  sdkArgs =
    assert lib.assertMsg (
      data.version == version
      && data.engineVersion == engineVersion
      && data.flutterHash == pin.flutterHash
    ) "sdkData must match the verified Cargo.toml Flutter pin and engine revision.";
    data // {
      inherit version engineVersion;
      inherit (pin) flutterHash;
      patches = (map (name: patchDir + "/${name}") (
        lib.remove "override-host-platform.patch" (builtins.attrNames (builtins.readDir patchDir))
      )) ++ [ hostPlatformPatch ];
      # mkFlutter requires these arguments even when using prebuilt engines.
      engineHashes = { };
      enginePatches = [ ];
      engineSwiftShaderHash = null;
      engineSwiftShaderRev = null;
    };
in
{
  inherit version engineVersion;

  # Keep engine separate: setting sdk.engine selects nixpkgs' local-engine API.
  flutterSdk = (flutterPackages.wrapFlutter (flutterPackages.mkFlutter sdkArgs)).override {
    supportedTargetFlutterPlatforms = [ "universal" "linux" ];
  };

  flutterEngine = stdenvNoCC.mkDerivation {
    pname = "veshell-flutter-engine";
    inherit version;
    src = fetchurl {
      url = "https://github.com/meta-flutter/flutter-engine/releases/download/linux-engine-sdk-release-${arch}-${engineVersion}/linux-engine-sdk-release-${arch}-${engineVersion}.tar.gz";
      hash = pin.releaseEngineHashes.${system};
    };
    sourceRoot = "flutter/engine/src/out/linux_release_${if arch == "x86_64" then "x64" else arch}/engine-sdk";
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ libGL stdenv.cc.cc.lib ];
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      install -Dm644 include/flutter_embedder.h "$out/flutter_embedder.h"
      install -Dm755 lib/libflutter_engine.so "$out/release/libflutter_engine.so"
      runHook postInstall
    '';
    passthru = {
      inherit engineVersion;
      runtimeMode = "release";
    };
    meta = {
      description = "Prebuilt release Flutter embedder engine matching Veshell's SDK pin";
      license = lib.licenses.bsd3;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" "aarch64-linux" ];
    };
  };
}
