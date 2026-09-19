{
  lib,
  fleetLib,
}: let
  inherit (builtins) attrValues mapAttrs filter elem;
  inherit (lib) mapAttrs' nameValuePair;

  roleFor = hostName: service:
    if service.primary == hostName
    then "primary"
    else if elem hostName (service.backups or [])
    then "backup"
    else null;
in {
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
    address = fleetLib.primaryIpV4 proxyHost;
    routes = mapAttrs' (
      serviceName: service: let
        upstreamHost = fleet.hosts.${service.primary};
      in
        nameValuePair "${serviceName}.${upstreamHost.name}.${fleet.domain}" {
          inherit serviceName;
          hostName = upstreamHost.name;
          upstream = "${fleetLib.primaryIpV4 upstreamHost}:${toString (service.proxyPort or service.port)}";
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
