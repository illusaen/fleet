{
  modules.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [nautilus libheif];
    environment.pathsToLink = ["share/thumbnailers"];

    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = "alacritty";
    };

    services = {
      gvfs.enable = true;
      udisks2.enable = true;
      gnome.sushi.enable = true;
    };
  };
}
