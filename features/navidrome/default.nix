let
  serviceSecrets = {hosts, ...}:
    map (hostName: {
      secret = "shared/navidrome-env.age";
      inherit hostName;
    })
    hosts;
in {
  inherit serviceSecrets;

  tests.serviceSecrets =
    serviceSecrets {
      hosts = ["odin" "huginn"];
    }
    == [
      {
        secret = "shared/navidrome-env.age";
        hostName = "odin";
      }
      {
        secret = "shared/navidrome-env.age";
        hostName = "huginn";
      }
    ];

  modules.nixos = {
    config,
    host,
    lib,
    helpers,
    options,
    ...
  }: let
    service = helpers.requireRoutedService host "navidrome";
    secretFile = ../../secrets/shared/navidrome-env.age;
  in
    lib.mkMerge [
      {
        services.navidrome =
          {
            enable = true;
            openFirewall = true;
            settings = {
              Address = "0.0.0.0";
              Port = service.port;
              DataFolder = "/var/lib/navidrome";
              MusicFolder = "/srv/music";
            };
          }
          // {
            environmentFile = lib.mkIf (builtins.pathExists secretFile) config.age.secrets.navidrome-env.path;
          };
      }
      (lib.mkIf (builtins.pathExists secretFile) {
        age.secrets.navidrome-env = {
          file = secretFile;
          owner = "navidrome";
          group = "navidrome";
        };
      })
      (lib.optionalAttrs (options ? persist) {
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
      })
    ];
}
