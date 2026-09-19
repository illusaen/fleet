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

  mkHostConfiguration = hostName: fleetHost: let
    host =
      fleetHost
      // {
        services = serviceLib.servicesForHost hostName fleet.services;
      };
    user = fleet.users.${host.owner};
  in {
    inherit host;
    modules = featureLib.modulesForHost host;
    pkgs = systemContexts.${host.system}.pkgs;
    specialArgs = {
      inherit fleet host user;
      helpers = {
        inherit (serviceLib) hostIps primaryIpV4 requireRoutedService reverseProxy;
      };
    };
  };

  mkNixosConfiguration = _hostName: {
    host,
    modules,
    pkgs,
    specialArgs,
  }:
    lib.nixosSystem {
      inherit (host) system;
      modules = [{nixpkgs.pkgs = pkgs;}] ++ modules;
      inherit specialArgs;
    };
in rec {
  hostConfigurations = builtins.mapAttrs mkHostConfiguration nixosHosts;
  nixosConfigurations = builtins.mapAttrs mkNixosConfiguration hostConfigurations;
}
