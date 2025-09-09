{
  description = "Development environment with Flutter and Rust";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}:
    let
      flutterHash = "sha256-s5T16+cMmL2ustJQjwFbfS8G+/TJW/WCEF1IO4WgbXQ=";
      flutterEngineHash = "sha256-XNZGEFE7ryNhA9Fc33n0v/uq7+IjdDDAMpqEVECRxws=";
    in
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      # Parse Flutter version from Cargo metadata
      cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
      flutterVersion = cargoToml.package.metadata.flutter_version;

      # Get Flutter SDK from GitHub
      flutterNixpkgs = pkgs.flutter332; # TODO build flutter from flutterVersion
      flutter = assert lib.assertMsg
        (flutterNixpkgs.version == flutterVersion)
        "Flutter version mismatch between cargo (${flutterVersion}) and nixpkgs (${flutterNixpkgs.version})";
        flutterNixpkgs;
      flutterSrc = pkgs.fetchFromGitHub {
        owner = "flutter";
        repo = "flutter";
        rev = flutterVersion;
        sha256 = flutterHash;
      };

      # Parse Flutter engine revision from Flutter
      engineRevisionFile = "${flutterSrc}/bin/internal/engine.version";
      engineRevision = lib.strings.removeSuffix "\n" (builtins.readFile engineRevisionFile);

      # Get Flutter Engine from GitHub
      flutterEngine = pkgs.stdenv.mkDerivation rec {
        pname = "flutter-engine";
        version = engineRevision;

        src = pkgs.fetchurl {
          name = "flutter-engine-${version}.tar.gz";
          url = "https://github.com/meta-flutter/flutter-engine/releases/download/linux-engine-sdk-debug-x86_64-${version}/linux-engine-sdk-debug-x86_64-${version}.tar.gz";
          sha256 = flutterEngineHash;
        };

        nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];

        unpackPhase = ''
          runHook preUnpack
          mkdir -p $out
          tar -xzf $src
          mv flutter/engine/src/out/linux_debug_x64/engine-sdk/* $out/
          runHook postUnpack
        '';

        meta = with lib; {
          description = "Flutter engine libraries for Linux";
          homepage = "https://flutter.dev";
          license = licenses.bsd3;
          platforms = platforms.linux;
        };
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          clang
          cmake
          ninja
          pkg-config
          rustc
          cargo
          rustfmt
          clippy
          rust-analyzer
          gtk3
          sysprof
          libsysprof-capture
          pcre2
          openssl
          systemd
          seatd
          unzip
          jq
          git
          libxkbcommon
          libinput
          libgbm
          xwayland
          pulseaudio
        ];

        shellHook = ''
          export RUST_BACKTRACE=1
          export SKIP_FLUTTER_ENGINE_DOWNLOAD=1
          export FLUTTER_PATH=${flutter}
          export FLUTTER_ENGINE_PATH=${flutterEngine}
          export LIBCLANG_PATH=${pkgs.libclang.lib}/lib
          export LD_LIBRARY_PATH=${pkgs.wayland}/lib:${pkgs.pulseaudio}/lib

          echo "=== Flutter Installation ==="

          # Symlink Flutter SDK
          if [ -d ".flutter_sdk" ] && [ ! -L ".flutter_sdk" ]; then
            echo "Removing existing .flutter_sdk directory..."
            rm -rf .flutter_sdk
          fi
          echo "Linking Flutter SDK..."
          ln -sfn ${flutter} .flutter_sdk

          # Symlink Flutter Engine
          echo "Linking Flutter Engine..."
          mkdir -p extra/third_party/flutter_engine/debug
          ln -sf "${flutterEngine}/lib/libflutter_engine.so" extra/third_party/flutter_engine/debug/libflutter_engine.so
          ln -sf "${flutterEngine}/include/flutter_embedder.h" extra/third_party/flutter_engine/flutter_embedder.h

          echo "=== Version Information ==="
          echo "Flutter version: $(${flutter}/bin/flutter --version --machine | jq -r '.flutterVersion')"
          echo "Dart version: $(${flutter}/bin/flutter --version --machine | jq -r '.dartSdkVersion')"
          echo "Engine revision: $(${flutter}/bin/flutter --version --machine | jq -r '.engineRevision')"
          echo "Channel: $(${flutter}/bin/flutter --version --machine | jq -r '.channel')"
        '';
      };
    };
}
