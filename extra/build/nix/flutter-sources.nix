{ fetchurl, fetchgit, lib, stdenv, cacert }:

let
  flutterVersion = "3.3.0"; # Replace with your desired version
  flutterHash = "your-commit-hash"; # Replace with your desired commit hash
in
stdenv.mkDerivation {
  pname = "flutter-sources";
  version = flutterVersion;

  src = fetchgit {
    url = "https://github.com/flutter/flutter.git";
    rev = flutterHash;
    sha256 = "0000000000000000000000000000000000000000000000000000"; # Replace with the actual hash
  };

  nativeBuildInputs = [ cacert ];

  NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  buildPhase = ''
    mkdir -p $out/src
    cp -r ${src}/* $out/src/
  '';

  meta = with lib; {
    description = "Flutter sources for version ${flutterVersion}";
    homepage = "https://flutter.dev";
    license = licenses.bsd3;
    maintainers = with maintainers; [ yourGitHubUsername ];
  };
}