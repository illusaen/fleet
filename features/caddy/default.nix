{
  modules.nixos = {
    config,
    fleet,
    lib,
    helpers,
    options,
    ...
  }: let
    inherit ((helpers.reverseProxy fleet)) routes;
  in
    lib.mkMerge [
      {
        services.caddy = {
          enable = true;
          openFirewall = true;
          virtualHosts =
            builtins.mapAttrs (_name: route: {
              extraConfig = ''
                reverse_proxy http://${route.upstream}
                tls internal
              '';
            })
            routes;
        };
      }
      (lib.optionalAttrs (options ? persist) {
        persist.directories = [
          {
            directory = config.services.caddy.dataDir;
            user = "caddy";
            group = "caddy";
            mode = "0700";
          }
          {
            directory = config.services.caddy.logDir;
            user = "caddy";
            group = "caddy";
            mode = "0750";
          }
        ];
      })
    ];
}
