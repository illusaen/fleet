{
  modules.nixos = {
    pkgs,
    lib,
    options,
    ...
  }: let
    wrappedYtDlp = pkgs.writeShellApplication {
      name = "yt-dlp";
      text = ''
        exec ${pkgs.yt-dlp}/bin/yt-dlp -t aac --cookies-from-browser chrome "$@"
      '';
    };
    music = pkgs.pear-desktop;
  in
    lib.mkMerge [
      {
        environment.systemPackages = [music wrappedYtDlp];
        systemdAutostart = [{package = music;}];
      }
      (lib.optionalAttrs (options ? persistUser) {
        persistUser.directories = [
          ".config/YouTube Music"
        ];
      })
    ];
}
