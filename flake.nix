{
  description = "Attribute-driven static JSON codec generation for MoonBit";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    moonbit-overlay = {
      url = "github:moonbit-community/moonbit-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    moon-nix = {
      url = "github:totto2727-org/moon-nix/794cab241c4ca8892646c441d52a5d3633c914b4";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.moonbit-overlay.follows = "moonbit-overlay";
    };
    moon-registry = {
      url = "git+https://mooncakes.io/git/index";
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
