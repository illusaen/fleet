{
  modules.nixos = {
    pkgs,
    lib,
    ...
  }: let
    wrappedYtDlp = pkgs.writeShellApplication {
      name = "ytd";
      text = ''
        exec ${pkgs.yt-dlp}/bin/yt-dlp -f bestaudio --cookies-from-browser chrome+gnomekeyring --no-playlist "$@"
      '';
    };
    music = pkgs.mpv.override {scripts = with pkgs.mpvScripts; [mpris uosc visualizer];};
  in {
    environment.systemPackages = [music wrappedYtDlp];
    systemdAutostart = [
      {
        package = music;
        exec = "${lib.getExe music} --loop-playlist=inf %h/Projects/music";
      }
    ];
  };
}
