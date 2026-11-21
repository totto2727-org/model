{
  pkgs,
  moonNix,
  toolchain,
  moonRegistryIndex,
}:
(moonNix.lib.mkMoonNix { inherit pkgs toolchain; }).buildProject {
  src = ./src/cmd/model_gen;
  registry = moonRegistryIndex.outPath;
  localSources = [ ./. ];
}
