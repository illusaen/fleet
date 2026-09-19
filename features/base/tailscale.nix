{
  modules.nixos = {
    config,
    lib,
    options,
    ...
  }:
    lib.mkMerge [
      {
        services.tailscale.enable = true;

        systemd.services.tailscaled.serviceConfig.Environment = [
          "TS_DEBUG_FIREWALL_MODE=nftables"
        ];

        networking = {
          nftables.enable = true;
          firewall = {
            enable = true;
            trustedInterfaces = ["tailscale0"];
            allowedUDPPorts = [config.services.tailscale.port];
          };
        };
      }
      (lib.optionalAttrs (options ? persist) {
        persist.directories = ["/var/lib/tailscale"];
      })
    ];
}
