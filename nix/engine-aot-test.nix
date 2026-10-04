# Optional headless compiler/loader smoke test; no Flutter rendering session.
{ lib, runCommand, writeText, stdenv, engine, runtime ? null, shellBundle ? null }:
let
  localEngine = "${engine}/out/${engine.outName}";
  includePath = if runtime == null then localEngine else "${runtime}/include";
  libraryPath = if runtime == null then localEngine else "${runtime}/lib";
  main = writeText "engine-aot-main.dart" ''
    import 'dart:ui';

    @pragma('vm:entry-point')
    void main() {
      print(PlatformDispatcher.instance.views.length);
    }
  '';
  loader = writeText "engine-aot-loader.c" ''
    #include <stdio.h>
    #include "flutter_embedder.h"

    int main(int argc, char **argv) {
      if (argc != 2 || !FlutterEngineRunsAOTCompiledDartCode()) {
        return 1;
      }
      FlutterEngineAOTDataSource source = {
        .type = kFlutterEngineAOTDataSourceTypeElfPath,
        .elf_path = argv[1],
      };
      FlutterEngineAOTData data = NULL;
      FlutterEngineResult result = FlutterEngineCreateAOTData(&source, &data);
      if (result != kSuccess || data == NULL) {
        fprintf(stderr, "FlutterEngineCreateAOTData failed: %d\n", result);
        return 1;
      }
      return FlutterEngineCollectAOTData(data) == kSuccess ? 0 : 1;
    }
  '';
in
runCommand "flutter-engine-aot-test-${engine.version}" {
  nativeBuildInputs = [ stdenv.cc ];
} (lib.optionalString (shellBundle == null) ''
  ${engine.dart}/bin/dartaotruntime \
    ${engine.dart}/bin/snapshots/frontend_server_aot.dart.snapshot \
    --sdk-root=${localEngine}/flutter_patched_sdk_product \
    --target=flutter --target-os=linux --aot --tfa \
    -Ddart.vm.product=true -Ddart.vm.profile=false --output-dill=app.dill ${main}
  test -s app.dill
  ${localEngine}/gen_snapshot --deterministic --snapshot_kind=app-aot-elf --elf=libapp.so app.dill
'' + ''
  $CC -std=c11 -I${includePath} ${loader} \
    -L${libraryPath} -Wl,-rpath,${libraryPath} -lflutter_engine -o aot-loader
  elf=${if shellBundle == null then ''"$PWD/libapp.so"'' else "${shellBundle}/lib/libapp.so"}
  ./aot-loader "$elf"
  mkdir -p "$out"
  cp "$elf" "$out/libapp.so"
'')
