{
  modules.nixos = {
    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true;
      systemd.enable = true;
    };

    services.power-profiles-daemon.enable = false;

    systemd.user.services.noctalia.environment.NOCTALIA_CONFIG_HOME = "%h/.local/state/nix-theme/current";

    nix.settings = {
      extra-substituters = [
        "https://noctalia.cachix.org"
      ];
      extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };
  };
}
