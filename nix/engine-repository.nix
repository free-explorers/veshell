# An immutable source pin, not a download of prebuilt engine binaries.
let
  pin = builtins.fromJSON (builtins.readFile ./engine-repository.json);
in
{
  source = builtins.fetchTarball {
    url = "https://github.com/${pin.repository}/archive/${pin.revision}.tar.gz";
    inherit (pin) sha256;
  };
  inherit (pin) revision;
}
