{
  description = "Veshell — an innovative not-desktop environment built with Flutter and Rust";

  # The Flutter engine packaging (free-explorers/flutter-engine-nix) is evaluated
  # against this exact nixpkgs revision; its default.nix pins the same one.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3";

  # Engine, SDK, shell and package closures are published here by the release
  # workflows, so `nix run` / `nix profile add` substitute instead of compiling
  # the Flutter engine. Nix applies a flake's substituters only when flake
  # configuration is accepted; docs/nixos.md shows the manual equivalent.
  nixConfig = {
    extra-substituters = [ "https://veshell.cachix.org" ];
    extra-trusted-public-keys = [
      "veshell.cachix.org-1:C8J71PCJ1Fx4+4shICPNsSOnGgijVEHZCTrWhbYyjOI="
    ];
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      veshell = import ./default.nix { inherit pkgs; };

      # Default the NixOS module to the flake's tested package; an explicit
      # programs.veshell.package still wins, and the module itself falls back to
      # the caller's pkgs when it is imported directly by path.
      module = { lib, ... }: {
        imports = [ ./nix/module.nix ];
        programs.veshell.package = lib.mkDefault veshell;
      };
    in
    {
      packages.${system} = {
        default = veshell;
        veshell = veshell;
        # The source-built engine alone, so the one expensive piece can be
        # pre-built with `nix build .#engine`. The app itself builds in minutes.
        engine = veshell.flutterEngine.passthru.sourceBuild;
      };

      overlays.default = final: prev: {
        veshell = import ./default.nix { pkgs = final; };
      };

      nixosModules = {
        default = module;
        veshell = module;
      };

      # Dependency-complete development shell for `nix develop` + `cargo run`.
      # The repository build still drives everything; the pinned SDK and source
      # engine are linked in when available so that it does not have to clone
      # the Flutter repository or download meta-flutter's engine.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          cargo rustc rustfmt clippy
          pkg-config cmake ninja clang git unzip xz zstd
          wayland libinput libdisplay-info seatd libgbm libxkbcommon pixman
          udev openssl pipewire gst_all_1.gstreamer gst_all_1.gst-plugins-base
          gtk3 libpulseaudio libGL libepoxy vulkan-loader fontconfig
        ];
        env = {
          # The shell builds a release bundle and the source engine is
          # release-only, so debug/profile engine modes are not wired here.
          VESHELL_FLUTTER_MODE = "release";
          SKIP_FLUTTER_ENGINE_DOWNLOAD = "1";
          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.wayland
            pkgs.libGL
            pkgs.libpulseaudio
          ];
        };
        shellHook = ''
          # Link the pinned SDK when it exposes the `version` file the build
          # checks; otherwise the recipe's own `git clone` flow installs it.
          if [ ! -e .flutter_sdk ] && [ -f ${veshell.flutterSdk}/version ]; then
            ln -sfn ${veshell.flutterSdk} .flutter_sdk
          fi
          engine_dir=extra/third_party/flutter_engine
          mkdir -p "$engine_dir/release"
          ln -sfn ${veshell.flutterEngine}/release/libflutter_engine.so "$engine_dir/release/libflutter_engine.so"
          ln -sfn ${veshell.flutterEngine}/flutter_embedder.h "$engine_dir/flutter_embedder.h"
          echo "Veshell dev shell: run 'cargo run' (release shell, pinned source engine)."
        '';
      };
    };
}
