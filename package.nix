{
  pkgs,
  moonNix,
  toolchain,
  moonRegistryIndex,
}:
let
  generator = (moonNix.lib.mkMoonNix { inherit pkgs toolchain; }).buildProject {
    src = ./src/cmd/serde-gen;
    registry = moonRegistryIndex.outPath;
    localSources = [ ./. ];
  };
in
generator.overrideAttrs (previous: {
  pname = "model_gen";
  postInstall = ''
    mv "$out/bin/${previous.meta.mainProgram}" "$out/bin/model_gen"
  '';
  meta = previous.meta // { mainProgram = "model_gen"; };
})
