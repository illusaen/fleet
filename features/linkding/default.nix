{
  modules.nixos = {
    host,
    lib,
    helpers,
    options,
    config,
    ...
  }: let
    service = helpers.requireRoutedService host "linkding";
  in
    lib.mkMerge [
      {
        services.linkding = {
          enable = true;
          openFirewall = true;
          inherit (service) port;
        };
      }
      (lib.optionalAttrs (options ? persist) {
        persist.directories = [
          {
            directory = config.services.linkding.dataDir;
            user = "linkding";
            group = "linkding";
            mode = "0700";
          }
        ];
      })
    ];
}
