# Independent of Veshell sources: this entry point measures the engine only.
let
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/774debe7a0d1b496e35677ad955a1011c6ff74f3.tar.gz";
    sha256 = "1japvhk1jlgc8sihm9gczwnv6fjanqsr1ji57vx67wbvqj88a34x";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };
in
pkgs.callPackage ./engine.nix { }
