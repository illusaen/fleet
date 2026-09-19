{
  modules.nixos = {pkgs, ...}: let
    wrappedYtDlp = pkgs.writeShellApplication {
      name = "yt-dlp";
      text = ''
        exec ${pkgs.yt-dlp}/bin/yt-dlp -t aac --cookies-from-browser chrome "$@"
      '';
    };
    music = pkgs.pear-desktop;
  in {
    environment.systemPackages = [music wrappedYtDlp];
    systemdAutostart = [{package = music;}];
    persistUser.directories = [".config/YouTube Music"];
  };
}
