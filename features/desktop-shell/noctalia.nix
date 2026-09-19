{inputs}: {
  modules.nixos = {pkgs, ...}: {
    imports = [inputs.noctalia.nixosModules.default];

    programs.noctalia = {
      enable = true;
      package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      recommendedServices.enable = true;
      systemd.enable = true;
    };

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
