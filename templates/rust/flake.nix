{
  description = "Rust project flake";

  inputs = {
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    devshell,
    nixpkgs,
    treefmt-nix,
    ...
  }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [devshell.overlays.default];
    };
    treefmtConfig = treefmt-nix.lib.evalModule pkgs {
      projectRootFile = "flake.nix";
      programs.alejandra.enable = true;
      programs.deadnix.enable = true;
      programs.statix.enable = true;
      programs.nixf-diagnose.enable = true;
      programs.rustfmt.enable = true;
      settings.excludes = ["*.patch" "*.png" "*.jpeg"];
    };
  in {
    formatter = treefmtConfig.config.build.wrapper;

    devShell = pkgs.devshell.mkShell (
      {extraModulesPath, ...}: {
        imports = [
          "${extraModulesPath}/git/hooks.nix"
          "${extraModulesPath}/language/rust.nix"
        ];

        devshell.packages = [
          pkgs.nixd
          treefmtConfig.config.build.wrapper
        ];

        commands = [
          {
            name = "build";
            command = "cargo build";
            help = "Build rust project";
          }
          {
            name = "run";
            command = "cargo run";
            help = "Run rust project";
          }
        ];

        git.hooks = {
          enable = true;
          pre-commit.text = ''
            treefmt
          '';
        };
      }
    );
  };
}
