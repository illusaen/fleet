{
  pkgs,
  treefmt,
}:
pkgs.devshell.mkShell (
  {extraModulesPath, ...}: {
    imports = [
      "${extraModulesPath}/git/hooks.nix"
    ];

    devshell = rec {
      name = "nix-fleet";
      motd = "\n🔨 Welcome to {45}${name}{reset}!\nType {45}'menu'{reset} for a list of commands.\n";
      packages = [
        pkgs.agenix
        pkgs.colmena
        treefmt
        pkgs.nixd
      ];
    };

    commands = [
      {
        package = pkgs.nh;
        help = "Build and deploy";
      }
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
