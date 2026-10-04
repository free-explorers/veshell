{ lib, root ? ../. }:
let
  compositorFiles = lib.fileset.unions [
    (root + "/Cargo.toml")
    (root + "/Cargo.lock")
    (root + "/.cargo/config.toml")
    (root + "/Makefile")
    (root + "/LICENSE")
    (root + "/src/embedder")
    (root + "/extra/build")
    (root + "/extra/assets")
    (root + "/extra/settings")
  ];
  shellFilter = path: type:
    lib.cleanSourceFilter path type
    && !(type == "directory" && builtins.elem (builtins.baseNameOf path) [
      "build" ".dart_tool" "ephemeral"
    ])
    && !(type == "regular" && (
      lib.hasSuffix ".g.dart" path || lib.hasSuffix ".freezed.dart" path
      || builtins.baseNameOf path == ".flutter-plugins-dependencies"
    ));
in
{
  inherit compositorFiles shellFilter;
  # The prebuilt-input Rust build never reads the Dart checkout or SDK.
  compositor = lib.fileset.toSource {
    inherit root;
    fileset = compositorFiles;
  };

  shell = lib.cleanSourceWith {
    src = root + "/src/shell";
    filter = shellFilter;
  };
}
