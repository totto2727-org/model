{
  pkgs,
  lib,
  moonNix,
  toolchain,
  moonRegistryIndex,
}:
let
  builders = moonNix.lib.mkMoonNix { inherit pkgs toolchain; };
  project = builders.parseManifest "module" (builtins.readFile ./moon.mod);
  cli = builders.parseManifest "module" (builtins.readFile ./src/cmd/serde-gen/moon.mod);
  manifest = import "${moonNix}/lib/pure/manifest.nix" { inherit lib; };
  resolver = import "${moonNix}/lib/pure/resolve.nix" { inherit lib manifest; };
  resolution = resolver.resolve {
    root = cli;
    localModules.${project.name} = {
      raw = project;
      key = project.name;
    };
    registry = toString moonRegistryIndex;
  };
  # Remove each patch when the corresponding Mooncakes release builds on our SDK.
  compatibility = {
    "totto2727/admiral@0.6.5" = ./patches/admiral.patch;
    "totto2727/lens@0.4.3" = ./patches/lens.patch;
    "mizchi/tui@0.10.2" = ./patches/tui.patch;
  };
  compatibleModules = lib.mapAttrsToList (key: patch: {
    module = resolution.modules.${key};
    inherit patch;
  }) compatibility;
  archiveOf =
    module:
    pkgs.fetchurl {
      url = "https://download.mooncakes.io/user/${module.name}/${module.version}.zip";
      sha256 = module.entry.checksum;
    };
  cacheModule =
    module:
    ''install -Dm644 ${archiveOf module} "$MOON_HOME/registry/cache/${module.name}/${module.version}.zip"'';
  patchModule = { module, patch }: ''
    mkdir -p "deps/${module.name}"
    unzip -q ${archiveOf module} -d "deps/${module.name}"
    patch --batch --fuzz=0 -p1 -d deps < ${patch}
  '';
  workspace = builtins.toJSON (
    [
      "."
      "src/cmd/serde-gen"
    ]
    ++ map (item: "deps/${item.module.name}") compatibleModules
  );
in
pkgs.stdenv.mkDerivation {
  pname = "serde-gen";
  inherit (project) version;
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./moon.mod
      ./README.mbt.md
      ./src
    ];
  };
  nativeBuildInputs = [
    toolchain
    pkgs.unzip
  ];
  # Let Moon parse package manifests, including conditional imports (#cfg).
  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR"
    export MOON_HOME="$HOME/.moon"
    mkdir -p "$MOON_HOME/registry"
    cp -r ${moonRegistryIndex} "$MOON_HOME/registry/index"
    ${lib.concatMapStringsSep "\n" cacheModule (builtins.attrValues resolution.modules)}
    ${lib.concatMapStringsSep "\n" patchModule compatibleModules}
    printf '%s\n' 'members = ${workspace}' > moon.work
    moon build --target native --release ./src/cmd/serde-gen
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 _build/native/release/build/totto2727/serde-gen/serde-gen.exe "$out/bin/serde-gen"
    runHook postInstall
  '';
  meta = {
    inherit (project) description;
    homepage = project.repository;
    license = lib.meta.getLicenseFromSpdxId project.license;
    mainProgram = "serde-gen";
  };
}
