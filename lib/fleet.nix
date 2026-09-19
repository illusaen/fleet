{lib}: let
  inherit (builtins) attrValues head;
  inherit (lib) concatMap;
in rec {
  eval = rawFleet:
    (lib.evalModules {
      modules = [
        (import ../fleet/options/default.nix {inherit lib;})
        {fleet = rawFleet;}
      ];
    }).config.fleet;

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
}
