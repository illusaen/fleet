{
  featureLib,
  lib,
  systemContexts,
}: let
  serviceLib = import ../lib/service.nix {inherit lib;};

  fleet =
    (lib.evalModules {
      modules = [
        (import ../fleet/options {inherit lib;})
        {fleet = import ../fleet/config;}
      ];
    }).config.fleet;

  nixosHosts =
    lib.filterAttrs (
      _name: host: host.platform == "nixos"
    )
    fleet.hosts;

  mkNixosConfiguration = hostName: fleetHost: let
    host =
      fleetHost
      // {
        services = serviceLib.servicesForHost hostName fleet.services;
      };
    user = fleet.users.${host.owner};
  in
    lib.nixosSystem {
      inherit (host) system;
      modules =
        [
          {nixpkgs.pkgs = systemContexts.${host.system}.pkgs;}
        ]
        ++ featureLib.modulesForHost host;
      specialArgs = {
        inherit fleet host user;
        helpers = {
          inherit (serviceLib) hostIps primaryIpV4 requireRoutedService reverseProxy;
        };
      };
    };
in {
  nixosConfigurations = builtins.mapAttrs mkNixosConfiguration nixosHosts;
}
