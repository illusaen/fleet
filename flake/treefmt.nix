{treefmt-nix}: pkgs:
treefmt-nix.lib.evalModule pkgs {
  projectRootFile = "flake.nix";
  programs.alejandra.enable = true;
  programs.deadnix.enable = true;
  programs.statix.enable = true;
  programs.shellcheck.enable = true;
  programs.ruff.enable = true;
  settings.excludes = ["*.patch" "*.png" "*.jpeg"];
}
