# flutter-engine-nix's engineFor at the revision flake.lock pins, for
# evaluation without flakes: its default.nix takes the same arguments. The
# flake passes the input's own lib.engineFor instead, so overriding the input
# applies.
let
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  locked = lock.nodes.${lock.nodes.${lock.root}.inputs.flutter-engine-nix}.locked;
  source = builtins.fetchTarball {
    url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  };
in
args: import source args
