{
  modules.nixos = {
    config,
    host,
    lib,
    helpers,
    ...
  }: let
    service = helpers.requireRoutedService host "navidrome";
    secretFile = ../../secrets/shared/navidrome-env.age;
    hasSecret = builtins.pathExists secretFile;
  in {
    services.navidrome = {
      enable = true;
      openFirewall = true;
      environmentFile = lib.mkIf hasSecret config.age.secrets.navidrome-env.path;
      settings = {
        Address = "0.0.0.0";
        Port = service.port;
        DataFolder = "/var/lib/navidrome";
        MusicFolder = "/srv/music";
      };
    };

    age.secrets.navidrome-env = lib.mkIf hasSecret {
      file = secretFile;
      owner = "navidrome";
      group = "navidrome";
    };

    persist.directories = [
      {
        directory = "/var/lib/navidrome";
        user = "navidrome";
        group = "navidrome";
        mode = "0700";
      }
      {
        directory = "/srv/music";
        user = "navidrome";
        group = "navidrome";
        mode = "0750";
      }
    ];
  };
}
