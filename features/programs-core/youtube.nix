{
  modules.nixos = {pkgs, ...}: let
    wrappedYtDlp = pkgs.writeShellApplication {
      name = "ytd";
      text = ''
        exec ${pkgs.yt-dlp}/bin/yt-dlp -f bestaudio --cookies-from-browser chrome+gnomekeyring --no-playlist "$@"
      '';
    };
    music = pkgs.pear-desktop;
  in {
    environment.systemPackages = [music wrappedYtDlp (pkgs.mpv.override {scripts = with pkgs.mpvScripts; [mpris uosc];})];
    systemdAutostart = [{package = music;}];
    persistUser.directories = [".config/YouTube Music"];
  };
}
