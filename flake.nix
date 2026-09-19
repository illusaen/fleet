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
    nixpkgs,
    treefmt-nix,
    colmena,
    ...
  } @ inputs: let
    forAllSystems = f:
      nixpkgs.lib.genAttrs (import ./flake/systems.nix) (system:
        f {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [(import ./flake/packages.nix {inherit (nixpkgs) lib;})];
          };
          inherit system;
        });
    treefmtFor = import ./flake/treefmt.nix {inherit treefmt-nix;};
  in
    {
      devShells = forAllSystems ({
        system,
        pkgs,
      }: {
        default = import ./flake/devshell.nix {
          inherit inputs system pkgs;
          treefmt = treefmtFor pkgs;
        };
      });
      formatter = forAllSystems ({pkgs, ...}: treefmtFor pkgs);
      packages = forAllSystems ({pkgs, ...}: pkgs.local);
      colmenaHive = import ./flake/hive.nix {inherit colmena;};
    }
    // import ./flake/configurations.nix {inherit inputs;};
}
