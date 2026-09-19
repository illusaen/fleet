{
  modules.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      inkscape
      bambu-studio
      image-roll
    ];

    xdg.mime.defaultApplications."image/*" = "com.github.weclaw1.ImageRoll.desktop";
    persistUser.directories = [".config/BambuStudio"];
  };
}
