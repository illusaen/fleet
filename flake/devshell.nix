{
  inputs,
  system,
  pkgs,
  treefmt,
}:
inputs.devshell.legacyPackages.${system}.mkShell (
  {extraModulesPath, ...}: {
    imports = [
      "${extraModulesPath}/git/hooks.nix"
    ];

    devshell = rec {
      name = "nix-fleet";
      motd = "\n🔨 Welcome to {45}${name}{reset}!\nType {45}'menu'{reset} for a list of commands.\n";
      packages = [
        inputs.agenix.packages.${system}.agenix
        inputs.colmena.packages.${system}.colmena
        treefmt
        pkgs.nixd
      ];
    };

    commands = [
      {
        package = pkgs.nix-tree;
        help = "Interactively browse dependency graphs of Nix derivations";
      }
    ];

    git.hooks = {
      enable = true;
      pre-commit.text = ''
        treefmt
      '';
    };
  }
)
