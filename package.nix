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
  manifest = import "${moonNix}/lib/pure/manifest.nix" { inherit lib; };
  resolver = import "${moonNix}/lib/pure/resolve.nix" { inherit lib manifest; };
  resolution = resolver.resolve {
    root = project;
    registry = toString moonRegistryIndex;
  };
  cacheModule = module:
    let
      archive = pkgs.fetchurl {
        url = "https://download.mooncakes.io/user/${module.name}/${module.version}.zip";
        sha256 = module.entry.checksum;
      };
    in
    ''install -Dm644 ${archive} "$MOON_HOME/registry/cache/${module.name}/${module.version}.zip"'';
in
pkgs.stdenv.mkDerivation {
  pname = "serde-gen";
  inherit (project) version;
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./moon.mod ./README.mbt.md ./src ];
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
    moon build --target native --release ./src/cmd/serde-gen
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 _build/native/release/build/cmd/serde-gen/serde-gen.exe "$out/bin/serde-gen"
    runHook postInstall
  '';
  meta = {
    inherit (project) description;
    homepage = project.repository;
    license = lib.meta.getLicenseFromSpdxId project.license;
    mainProgram = "serde-gen";
  };
}
