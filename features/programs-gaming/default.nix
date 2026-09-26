{
  imports = [./vesktop.nix];

  modules.nixos = {pkgs, ...}: {
    programs.steam = {
      enable = true;
      package = pkgs.millennium-steam;
    };

    persistUser.directories = [".local/share/Steam"];
  };
}
