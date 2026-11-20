{
  pkgs,
  moonNix,
  toolchain,
  moonRegistryIndex,
}:
(moonNix.lib.mkMoonNix { inherit pkgs toolchain; }).buildProject {
  src = ./src/cmd/serde-gen;
  registry = moonRegistryIndex.outPath;
  localSources = [ ./. ];
}
