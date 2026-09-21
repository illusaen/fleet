{
  modules.nixos = {pkgs, ...}: let
    package = pkgs.vesktop;
  in {
    environment.systemPackages = [package];
    systemdAutostart = [
      {inherit package;}
    ];
    persistUser.directories = [".config/vesktop/sessionData"];
  };
}
