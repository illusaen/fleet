{
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos-cuda.org"
      "https://colmena.cachix.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://illusaen.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "illusaen.cachix.org-1:fxa0K6z978YmVBWgy58TJp8qnw2XxWjC997ArJzzuxk="
    ];
  };

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    base16.url = "github:SenchoPens/base16.nix/main";
    colmena = {
      url = "github:nix-community/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.stable.follows = "nixpkgs";
    };
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation.url = "github:nix-community/preservation";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    treefmt-nix,
    colmena,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;

    featureLib = import ./lib/feature.nix {inherit inputs lib;};
    systemContexts = lib.genAttrs (import ./flake/systems.nix) (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = import ./flake/overlays.nix {inherit inputs lib;};
        config.allowUnfree = true;
      };
    in {
      inherit pkgs system;
      treefmt = (import ./flake/treefmt.nix {inherit treefmt-nix;}) pkgs;
    });

    configurations = import ./flake/configurations.nix {
      inherit featureLib lib systemContexts;
    };
    forAllSystems = f: lib.mapAttrs (_system: f) systemContexts;
  in {
    checks = forAllSystems ({treefmt, ...}: {treefmt = treefmt.config.build.check self;});
    devShells = forAllSystems ({
      pkgs,
      treefmt,
      ...
    }: {
      default = import ./flake/devshell.nix {
        inherit pkgs;
        treefmt = treefmt.config.build.wrapper;
      };
    });
    formatter = forAllSystems ({treefmt, ...}: treefmt.config.build.wrapper);
    packages = forAllSystems ({
      pkgs,
      system,
      ...
    }:
      pkgs.local
      // lib.optionalAttrs (system == "x86_64-linux") {
        inherit (pkgs) bambu-studio llama-cpp-cuda;
      });
    colmenaHive = import ./flake/hive.nix {
      inherit colmena lib;
      inherit (configurations) hostConfigurations;
    };
    inherit (configurations) nixosConfigurations;
  };
}
