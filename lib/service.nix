{lib}: let
  inherit (builtins) attrValues mapAttrs filter elem head;
  inherit (lib) mapAttrs' nameValuePair concatMap;

  roleFor = hostName: service:
    if service.primary == hostName
    then "primary"
    else if elem hostName (service.backups or [])
    then "backup"
    else null;
in rec {
  hostIps = family: host:
    concatMap (
      interface: let
        address = interface.${family} or null;
      in
        if address == null
        then []
        else [(head (lib.splitString "/" address))]
    ) (attrValues (host.networkInterfaces or {}));

  primaryIpV4 = host: let
    ips = hostIps "ipv4" host;
  in
    if ips == []
    then throw "No IPV4 addresses for ${host.name}."
    else head ips;

  requireRoutedService = host: name: let
    service = lib.findFirst (service: service.name == name) null (host.services or []);
  in
    if service == null
    then throw "${name} feature requires a routed ${name} service for host '${host.name}'"
    else service;

  reverseProxy = fleet: let
    caddy = fleet.services.caddy or (throw "the fleet has no caddy service");
    proxyHost = fleet.hosts.${caddy.primary};
  in {
    address = primaryIpV4 proxyHost;
    routes = mapAttrs' (
      serviceName: service: let
        upstreamHost = fleet.hosts.${service.primary};
      in
        nameValuePair "${serviceName}.${upstreamHost.name}.${fleet.domain}" {
          inherit serviceName;
          hostName = upstreamHost.name;
          upstream = "${primaryIpV4 upstreamHost}:${toString (service.proxyPort or service.port)}";
        }
    ) (removeAttrs fleet.services ["caddy"]);
  };

  servicesForHost = hostName: services:
    lib.pipe services [
      (mapAttrs (name: service:
        service
        // {
          inherit name;
          role = roleFor hostName service;
        }))
      attrValues
      (filter (s: s.role != null))
    ];
}
