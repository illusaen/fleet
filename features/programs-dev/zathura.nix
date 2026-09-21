{
  modules.nixos = {pkgs, ...}: {
    xdg.mime.defaultApplications = let
      reader = "org.pwmt.zathura.desktop";
    in {
      "application/pdf" = reader;
      "application/epub+zip" = reader;
      "application/postscript" = reader;
    };

    environment.systemPackages = [pkgs.zathura];
  };
}
