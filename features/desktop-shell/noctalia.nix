{inputs}: {
  modules.nixos = {pkgs, ...}: {
    imports = [inputs.noctalia.nixosModules.default];
    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true;
      systemd.enable = true;
      package = pkgs.noctalia;
    };

    services.upower.enable = true;
    services.power-profiles-daemon.enable = false;
    systemd.user.services.noctalia.environment.NOCTALIA_CONFIG_HOME = "%h/.config";

    nix.settings = {
      extra-substituters = [
        "https://noctalia.cachix.org"
      ];
      extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };

    persistUser.directories = [".local/state/noctalia"];
  };
}
