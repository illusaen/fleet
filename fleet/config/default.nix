let
  fleet = import ./fleet.nix;
in
  fleet
  // {
    hosts = import ./hosts.nix;
    users = import ./users.nix;
    groups = import ./groups.nix;
    services = import ./services.nix;
  }
