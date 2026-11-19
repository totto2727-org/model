{
  pkgs,
  lib,
  moonNix,
  toolchain,
  moonRegistryIndex,
  admiralSrc,
}:
let
  builders = moonNix.lib.mkMoonNix { inherit pkgs toolchain; };
  project = builders.parseManifest "module" (builtins.readFile ./moon.mod);
in
(builders.buildNative {
  src = ./src/cmd/serde-gen;
  localSources = [
    ./.
    admiralSrc
  ];
  registry = moonRegistryIndex.outPath;
}).overrideAttrs
  (previous: {
    version = project.version;
    meta = previous.meta // {
      inherit (project) description;
      homepage = project.repository;
      license = lib.meta.getLicenseFromSpdxId project.license;
    };
  })
