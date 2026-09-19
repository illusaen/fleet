{
  modules.nixos = {config, ...}: {
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

    persist.directories = ["/var/lib/tailscale"];
  };
}
