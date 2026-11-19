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
  resolution = builders.resolveDependencies {
    root = cli;
    localModules.${project.name} = {
      raw = project;
      key = project.name;
    };
    registry = moonRegistryIndex.outPath;
  };
  archiveOf =
    module:
    pkgs.fetchurl {
      url = "https://download.mooncakes.io/user/${module.name}/${module.version}.zip";
      sha256 = module.entry.checksum;
    };
  cacheModule =
    module:
    ''install -Dm644 ${archiveOf module} "$MOON_HOME/registry/cache/${module.name}/${module.version}.zip"'';
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
  nativeBuildInputs = [ toolchain ];
  # Let Moon parse package manifests, including conditional imports (#cfg).
  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR"
    export MOON_HOME="$HOME/.moon"
    mkdir -p "$MOON_HOME/registry"
    cp -r ${moonRegistryIndex} "$MOON_HOME/registry/index"
    ${lib.concatMapStringsSep "\n" cacheModule (builtins.attrValues resolution.modules)}
    printf '%s\n' 'members = [".", "src/cmd/serde-gen"]' > moon.work
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
