{
  modules.nixos = {
    fleet,
    helpers,
    host,
    lib,
    ...
  }: let
    inherit (lib) pipe filterAttrs mapAttrs' nameValuePair optional mkIf;

    staticInterfaces = host.networkInterfaces or {};
    hasStaticInterfaces = staticInterfaces != {};
    fleetHosts = pipe fleet.hosts [
      (filterAttrs (name: _knownHost: name != host.name))
      (mapAttrs' (_name: knownHost:
        nameValuePair (helpers.primaryIpV4 knownHost) [
          knownHost.name
          "${knownHost.name}.${fleet.domain}"
        ]))
    ];
    mkNetwork = name: interface:
      nameValuePair "10-${name}" {
        matchConfig.Name = name;
        address =
          optional ((interface.ipv4 or null) != null) interface.ipv4
          ++ optional ((interface.ipv6 or null) != null) interface.ipv6;
        routes = [
          {Gateway = "192.168.1.1";}
          {Gateway = "fe80::1";}
        ];
        linkConfig.RequiredForOnline = "routable";
      };
  in {
    networking = {
      hostName = host.name or null;
      inherit (fleet) domain;
      inherit (host) hostId;
      hosts = fleetHosts;
      networkmanager.enable = !hasStaticInterfaces;
      useDHCP = !hasStaticInterfaces;
      useNetworkd = hasStaticInterfaces;
    };

    systemd.network = mkIf hasStaticInterfaces {
      enable = true;
      wait-online.anyInterface = true;
      networks = mapAttrs' mkNetwork staticInterfaces;
    };

    persist.directories = optional (!hasStaticInterfaces) "/etc/NetworkManager/system-connections";
  };
}
