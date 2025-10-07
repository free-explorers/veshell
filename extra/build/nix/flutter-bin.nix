{ lib, stdenv, flutterEngine, flutterSources }:

stdenv.mkDerivation {
  pname = "flutter-bin";
  version = "1.0.0";

  src = flutterSources;

  nativeBuildInputs = [ flutterEngine ];

  buildPhase = ''
    mkdir -p $out/bin
    cp -r ${flutterEngine}/bin/* $out/bin/
    cp -r ${src}/bin/* $out/bin/
  '';

  meta = with lib; {
    description = "Flutter binaries and engine artifacts";
    homepage = "https://flutter.dev";
    license = licenses.bsd3;
    maintainers = with maintainers; [ yourGitHubUsername ];
  };
}