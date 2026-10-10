{
  description = "Veshell — an innovative not-desktop environment built with Flutter and Rust";

  # The Flutter engine packaging (free-explorers/flutter-engine-nix) and the
  # release roots in nix/release.nix are evaluated against this exact nixpkgs
  # revision. Keep all three in step.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3";

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
        # The source-built engine, exposed so it can be built or cached on its
        # own; it is also what `nix build` pulls in for the package.
        engine = veshell.flutterEngine.passthru.sourceBuild;
        runtime = veshell.flutterEngine.passthru.runtime;
      };

      overlays.default = final: prev: {
        veshell = import ./default.nix { pkgs = final; };
      };

      nixosModules = {
        default = module;
        veshell = module;
      };
    };
}
