# Call with pkgs.callPackage ./dependencies.nix {}.
# Regenerate pubspec-lock.json from the repository root:
# nix-shell -p yq jq --run 'yq -s . src/shell/pubspec.lock | jq -S ".[0]" > nix/pubspec-lock.json'
{ lib }:
{
  pubspecLock = lib.importJSON ./pubspec-lock.json;

  # Verified fetchgit hashes for the lockfile's resolved-ref, keyed by package.
  gitHashes = {
    freedesktop_desktop_entry = "sha256-d9cjrgyRnmsOFED/v1namsGyXApDUZCTPga8Jjs6e2s=";
    material_design_icons_flutter = "sha256-T3edt6Lo0HmliE3H0OA2VRR9tmnYjJv4In8yO7zV54k=";
    ubuntu_session = "sha256-SGXw+Ym1tFC2jTFxJwh+K2Ep50pRN479oAs9fTDeWnI=";
  };

  # Verified with rustPlatform.fetchCargoVendor (nixpkgs 774debe7a0d1).
  cargoHash = "sha256-DxQpI/Guch8qqlZ5uZ1I5bXQLZgK6lSKoPLH6hIAGEw=";
}
