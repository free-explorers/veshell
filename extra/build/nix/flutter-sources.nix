{ lib, stdenv, cacert, callPackage, flutterHash, python312 }:

let

  depot_tools = callPackage ./depot_tools.nix { inherit lib stdenv cacert; };
  python3 = python312;
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

  nativeBuildInputs = [ 
    cacert 
    depot_tools 
    (python3.withPackages (
        ps: with ps; [
          httplib2
          six
        ]
      )) ];

  NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  unpackPhase = ''
    mkdir -p $out/src
    cp -r ${sources}/* $out/src/
    echo "${gclient}" > $out/src/.gclient
  '';

  buildPhase = ''
    export PATH=$PATH:${depot_tools}
    ls ${depot_tools}
    python3 ${depot_tools}/gclient.py sync --no-history --shallow --nohooks
  '';

  meta = with lib; {
    description = "Flutter sources for version ${flutterHash}";
    homepage = "https://flutter.dev";
    license = licenses.bsd3;
    maintainers = with maintainers; [ yourGitHubUsername ];
  };
}