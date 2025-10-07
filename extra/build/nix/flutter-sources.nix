{ lib, stdenv, cacert, flutterHash }:

let

  depot_tools = import ./depot_tools.nix { inherit lib stdenv cacert; };

  sources = builtins.fetchGit {
    url = "https://github.com/flutter/flutter.git";
    rev = flutterHash;
  };

   gclient = ''
    solutions = [
      {
        "name": "src/flutter",
        "url": "https://github.com/flutter/flutter.git@${flutterHash}",
        "managed": false,
        "custom_deps": {},
        "custom_vars": {
          "download_fuchsia_deps": false,
          "download_android_deps": false,
          "download_linux_deps": true,
          "setup_githooks": false,
          "download_esbuild": false,
          "download_dart_sdk": false,
          "host_cpu": "x64",
          "host_os": "linux",
        },
      },
    ]
    target_os = ["linux"]
  '';

in
stdenv.mkDerivation {
  pname = "flutter-sources";
  version = flutterHash;

  src = sources;

  nativeBuildInputs = [ cacert depot_tools ];

  NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  unpackPhase = ''
    mkdir -p $out/src
    cp -r ${sources}/* $out/src/
    echo "${gclient}" > $out/src/.gclient
  '';

  buildPhase = ''
    gclient sync
  '';

  meta = with lib; {
    description = "Flutter sources for version ${flutterHash}";
    homepage = "https://flutter.dev";
    license = licenses.bsd3;
    maintainers = with maintainers; [ yourGitHubUsername ];
  };
}