{inputs}: {
  modules.nixos = {pkgs, ...}: {
    imports = [inputs.umbriel.nixosModules.default];
    programs.umbriel = {
      enable = true;
      package = pkgs.umbriel;
      portalPackage = pkgs.xdg-desktop-portal-umbriel;
    };
  };
}
