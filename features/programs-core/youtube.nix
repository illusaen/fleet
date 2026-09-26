{
  modules.nixos = {pkgs, ...}: let
    wrappedYtDlp = pkgs.writeShellApplication {
      name = "ytd";
      text = ''
        exec ${pkgs.yt-dlp}/bin/yt-dlp -f bestaudio --cookies-from-browser chrome+gnomekeyring --no-playlist "$@"
      '';
    };
    music = pkgs.mpv.override {scripts = with pkgs.mpvScripts; [mpris uosc];};
  in {
    environment.systemPackages = [music wrappedYtDlp];
    systemdAutostart = [{package = music;}];
  };
}
