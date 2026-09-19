{inputs}: let
  inherit (inputs.nixpkgs) lib;

  fleetLib = import ../lib/fleet.nix {inherit lib;};
  fleet = fleetLib.eval (import ../fleet/config);
  serviceLib = import ../lib/service.nix {inherit lib fleetLib;};
  featureLib = import ../lib/feature.nix {inherit inputs lib;};
  localOverlay = import ./packages.nix {inherit lib;};

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
          {nixpkgs.overlays = [localOverlay];}
        ]
        ++ featureLib.modulesForHost host;
      specialArgs = {
        inherit fleet host user;
        helpers = {
          inherit (fleetLib) hostIps primaryIpV4;
          inherit (serviceLib) requireRoutedService reverseProxy;
        };
      };
    };
in {
  nixosConfigurations = builtins.mapAttrs mkNixosConfiguration nixosHosts;
}
