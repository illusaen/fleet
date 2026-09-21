{
  modules.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [starship];
    # environment.sessionVariables.STARSHIP_CONFIG = "${starshipSettings pkgs}";
  };
}
