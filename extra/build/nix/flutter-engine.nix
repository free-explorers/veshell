{ lib, stdenv, cacert, pkg-config, clang, cmake, ninja, dart, flutterSources, engineVersion }:

stdenv.mkDerivation {
  pname = "flutter-engine";
  version = engineVersion;

  src = flutterSources;

  nativeBuildInputs = [ cacert pkg-config clang cmake ninja dart ];

  buildInputs = [ dart ];

  buildPhase = ''
    export NIX_SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
    export PATH=${dart}/bin:$PATH
    export FLUTTER_ROOT=${flutterSources}

    mkdir -p $out/bin
    cd ${flutterSources}/src/flutter
    ./flutter/tools/gn --unoptimized --full-dart-sdk
    ninja -C out/host_debug_unoptimized
    cp -r out/host_debug_unoptimized $out/bin/
  '';

  meta = with lib; {
    description = "Flutter engine for version ${engineVersion}";
    homepage = "https://flutter.dev";
    license = licenses.bsd3;
    maintainers = with maintainers; [ yourGitHubUsername ];
  };
}