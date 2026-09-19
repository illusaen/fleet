{
  modules.nixos = {
    host,
    helpers,
    config,
    ...
  }: let
    service = helpers.requireRoutedService host "linkding";
  in {
    services.linkding = {
      enable = true;
      openFirewall = true;
      inherit (service) port;
    };

    persist.directories = [
      {
        directory = config.services.linkding.dataDir;
        user = "linkding";
        group = "linkding";
        mode = "0700";
      }
    ];
  };
}
