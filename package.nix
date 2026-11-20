{
  pkgs,
  moonNix,
  toolchain,
  moonRegistryIndex,
  admiralSrc,
}:
(moonNix.lib.mkMoonNix { inherit pkgs toolchain; }).buildProject {
  src = ./src/cmd/serde-gen;
  registry = moonRegistryIndex.outPath;
  localSources = [
    ./.
    admiralSrc
  ];
}
