{
  description = "Attribute-driven static JSON codec generation for MoonBit";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    moonbit-overlay = {
      url = "github:moonbit-community/moonbit-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    moon-nix = {
      url = "github:totto2727-org/moon-nix/36df10451b6bbe578b96d719897572ed7aa1c251";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.moonbit-overlay.follows = "moonbit-overlay";
    };
    moon-registry = {
      url = "git+https://mooncakes.io/git/index";
      flake = false;
    };
    admiral = {
      url = "github:totto2727-org/admiral/d4441fe9360acc24f59f3eb0c2a7ade859d1d498";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      moonbit-overlay,
      moon-nix,
      moon-registry,
      admiral,
      ...
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ moonbit-overlay.overlays.default ];
        };
      toolchainFor = pkgs: pkgs.moonbit-bin.latest;
      mkGenerator =
        pkgs:
        pkgs.callPackage ./package.nix {
          admiralSrc = admiral.outPath;
          moonNix = moon-nix;
          toolchain = toolchainFor pkgs;
          moonRegistryIndex = moon-registry;
        };
    in
    {
      overlays.default = _final: previous: {
        serde-gen = self.packages.${previous.stdenv.hostPlatform.system}.serde-gen;
      };

      packages = forEachSystem (
        system:
        let
          serde-gen = mkGenerator (mkPkgs system);
        in
        {
          inherit serde-gen;
          default = serde-gen;
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = mkPkgs system;
        in
        rec {
          ci = default.overrideAttrs (_: {
            shellHook = "";
          });
          default = pkgs.mkShell {
            packages = [
              (toolchainFor pkgs)
              self.packages.${system}.serde-gen
            ];
            shellHook = ''
              # Enable Git Hook
              vp config
            '';
          };
        }
      );
    };
}
